import Cocoa

// Cockpit Bar: a fork of claude-status-bar (MIT, m1ckc3s) whose session list is cockpit's. The menu bar side
// (splat animation, activity text, permission state, completion chime) is driven by the hook-written files in
// ~/.local/state/cockpit/bar/state.d, exactly as upstream. The dropdown rows come from `cockpit-bar --json`
// (due, running, snoozed and recent sessions with ticket, title, MRs and snooze), matched to the hook files by
// session id so each row shows what that session is doing right now.
final class StatusController: NSObject, NSMenuDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let baseDir = (NSHomeDirectory() as NSString).appendingPathComponent(".local/state/cockpit/bar")
    var stateDir: String { (baseDir as NSString).appendingPathComponent("state.d") }
    let providerPath = (Bundle.main.object(forInfoDictionaryKey: "CockpitBarProvider") as? String) ?? ""

    var pollTimer: Timer?
    var rowsTimer: Timer?
    var animTimer: Timer?
    var frameIdx = 0
    var markOutro = false

    // MARK: the hook side (one file per session, written by hooks/update.js)

    struct Session {
        var id: String, state: String, label: String, project: String, transcript: String
        var cwd: String
        var pid: Int32          // the session's `claude` process; kill(pid,0) drives liveness
        var started: Bool       // true once the session had real activity (a prompt/tool)
        var startedAt: Double, ts: Double
        var eff: String = ""    // effective state, recomputed once per tick in evaluate()

        init(json o: [String: Any], id: String) {
            self.id = id
            self.state = o["state"] as? String ?? "idle"
            self.label = o["label"] as? String ?? ""
            self.project = o["project"] as? String ?? ""
            self.transcript = o["transcript"] as? String ?? ""
            self.cwd = o["cwd"] as? String ?? ""
            self.pid = Int32(truncatingIfNeeded: (o["pid"] as? NSNumber)?.intValue ?? 0)
            self.started = o["started"] as? Bool ?? false
            self.startedAt = (o["startedAt"] as? NSNumber)?.doubleValue ?? 0
            self.ts = (o["ts"] as? NSNumber)?.doubleValue ?? 0
        }
    }
    var sessions: [String: Session] = [:]  // id -> latest parsed per-session state
    var fileMTimes: [String: Date] = [:]   // "<id>.json" -> last-parsed mtime (re-parse only on change)
    var prevState: [String: String] = [:]  // id -> previous raw state per session

    // MARK: the cockpit side (one row per session, from `cockpit-bar --json`)

    struct MR { var url: String, project: String, repo: String, iid: Int, title: String, state: String }
    struct Row {
        var id: String, group: Int, ticket: String, ticketURL: String, verb: String, title: String, repo: String, branch: String
        var live: Bool, tmux: String, kind: String
        var snoozed: Bool, due: Bool, snoozeText: String, snoozeShort: String, wakes: String
        var started: String, last: String
        var mrs: [MR]
        var stateIds: [String]
        var synthetic = false   // a hook-tracked session cockpit has not indexed yet (no prompt sent)

        init(json o: [String: Any]) {
            id = o["id"] as? String ?? ""
            group = (o["group"] as? NSNumber)?.intValue ?? 3
            ticket = o["ticket"] as? String ?? ""
            ticketURL = o["ticket_url"] as? String ?? ""
            verb = o["verb"] as? String ?? ""
            title = o["title"] as? String ?? ""
            repo = o["repo"] as? String ?? ""
            branch = o["branch"] as? String ?? ""
            let l = o["live"] as? [String: Any]
            live = l != nil
            tmux = l?["tmux"] as? String ?? ""
            kind = l?["kind"] as? String ?? ""
            snoozed = o["snoozed"] as? Bool ?? false
            due = o["due"] as? Bool ?? false
            snoozeText = o["snooze_text"] as? String ?? ""
            snoozeShort = o["snooze_short"] as? String ?? ""
            wakes = o["wakes"] as? String ?? ""
            started = o["started"] as? String ?? ""
            last = o["last"] as? String ?? ""
            mrs = (o["mrs"] as? [[String: Any]] ?? []).map { m in
                MR(url: m["url"] as? String ?? "", project: m["project"] as? String ?? "", repo: m["repo"] as? String ?? "",
                   iid: (m["iid"] as? NSNumber)?.intValue ?? 0, title: m["title"] as? String ?? "", state: m["state"] as? String ?? "")
            }
            stateIds = o["state_ids"] as? [String] ?? []
        }
        init(session s: Session) {
            id = s.id; group = 1; ticket = ""; ticketURL = ""; verb = ""; title = s.project.isEmpty ? "new session" : s.project; repo = s.project; branch = ""
            live = true; tmux = ""; kind = ""
            snoozed = false; due = false; snoozeText = ""; snoozeShort = ""; wakes = ""
            started = ""; last = ""; mrs = []; stateIds = [s.id]; synthetic = true
        }
    }
    var rows: [Row] = []
    var dueCount = 0
    var rowsLoading = false
    var rowsDirtyAt: Date?          // a hook file changed; reload the rows shortly after
    var lastRowsLoad = Date.distantPast
    let rowsInterval: TimeInterval = 5
    var menuIsOpen = false
    var rowMenuItems: [(item: NSMenuItem, row: Row)] = []

    // MARK: menu bar rendering state (verbatim from upstream)

    var activeBase = ""        // label without the elapsed clock
    var startedAt: Double = 0  // unix seconds the current turn began (0 = no clock)
    var activeColor: NSColor? = nil
    var lastTitleText: String? = nil
    var iconCache: [String: NSImage] = [:]
    var pillCache: [String: NSImage] = [:]
    var turnLineCache: [String: (mtime: Date?, line: String?)] = [:]

    let brand = NSColor(srgbRed: 0.851, green: 0.467, blue: 0.341, alpha: 1) // #d97757, Anthropic's "Orange" accent
    let amber = NSColor(srgbRed: 0.95, green: 0.73, blue: 0.18, alpha: 1) // "awaiting permission" yellow dot
    let frames: [NSImage] = StatusController.loadFrames()
    let spriteFPS: Double = 9

    enum AnimStyle: String { case web, code, crab, mark }
    var animStyle: AnimStyle = .web
    var showTimer = false
    var iconSystem = false // false = brand Orange; true = adaptive black/white (template image)
    var showLabel = true
    var sessionWord: [String: String] = [:] // id -> current thinking word; re-picked on each entry into "thinking"
    var soundThreshold: Double = 0  // 0 = off; else the min turn length (seconds) that chimes on completion
    var turnStart: [String: Double] = [:]  // id -> active turn start, for the completion-sound length gate
    lazy var completionSound: NSSound? = {
        guard let p = Bundle.main.path(forResource: "completion", ofType: "mp3"),
              let s = NSSound(contentsOfFile: p, byReference: true) else { return nil }
        s.volume = 0.7
        return s
    }()
    // Claude Code's SPINNER_VERBS, minus the hyphenated/tongue-twister ones.
    let thinkingWords = [
        "Accomplishing", "Actioning", "Actualizing", "Architecting", "Baking", "Beaming", "Beboppin'",
        "Befuddling", "Billowing", "Blanching", "Bloviating", "Boogieing", "Boondoggling", "Booping",
        "Bootstrapping", "Brewing", "Bunning", "Burrowing", "Calculating", "Canoodling", "Caramelizing",
        "Cascading", "Catapulting", "Cerebrating", "Channeling", "Channelling", "Churning", "Clauding",
        "Coalescing", "Cogitating", "Combobulating", "Composing", "Computing", "Concocting", "Considering",
        "Contemplating", "Cooking", "Crafting", "Creating", "Crunching", "Crystallizing", "Cultivating",
        "Deciphering", "Deliberating", "Determining", "Doing", "Doodling", "Drizzling", "Ebbing",
        "Effecting", "Elucidating", "Embellishing", "Enchanting", "Envisioning", "Evaporating", "Fermenting",
        "Finagling", "Flambéing", "Flowing", "Flummoxing", "Fluttering", "Forging", "Forming", "Frolicking",
        "Gallivanting", "Galloping", "Garnishing", "Generating", "Gesticulating", "Germinating", "Gitifying",
        "Grooving", "Gusting", "Harmonizing", "Hashing", "Hatching", "Herding", "Honking", "Hullaballooing",
        "Hyperspacing", "Ideating", "Imagining", "Improvising", "Incubating", "Inferring", "Infusing",
        "Ionizing", "Jitterbugging", "Julienning", "Kneading", "Leavening", "Levitating", "Lollygagging",
        "Manifesting", "Marinating", "Meandering", "Metamorphosing", "Misting", "Moonwalking", "Moseying",
        "Mulling", "Mustering", "Musing", "Nebulizing", "Nesting", "Noodling", "Nucleating", "Orbiting",
        "Orchestrating", "Osmosing", "Perambulating", "Percolating", "Perusing", "Pollinating", "Pondering",
        "Pontificating", "Pouncing", "Precipitating", "Processing", "Proofing", "Propagating", "Puttering",
        "Puzzling", "Quantumizing", "Razzmatazzing", "Reticulating", "Roosting", "Ruminating", "Sautéing",
        "Scampering", "Schlepping", "Scurrying", "Seasoning", "Shenaniganing", "Shimmying", "Simmering",
        "Skedaddling", "Sketching", "Slithering", "Smooshing", "Spelunking", "Spinning", "Sprouting",
        "Stewing", "Sublimating", "Swirling", "Swooping", "Symbioting", "Synthesizing", "Tempering",
        "Thinking", "Thundering", "Tinkering", "Tomfoolering", "Transfiguring", "Transmuting", "Twisting",
        "Undulating", "Unfurling", "Unravelling", "Vibing", "Waddling", "Wandering", "Warping",
        "Whirlpooling", "Whirring", "Whisking", "Wibbling", "Working", "Wrangling", "Zesting", "Zigzagging"]
    var iconColor: NSColor? { iconSystem ? nil : brand } // nil => render as an adaptive template
    let codeGlyphs = ["✻", "✽", "✶", "✳", "✢"]
    let codePeaks: [CGFloat] = [1.0, 1.0, 1.0, 1.0, 1.0]
    let codeDip: CGFloat = 0.14 // glyph shrinks to this at each swap
    let codeSub = 18            // sub-frames per glyph (tween smoothness)
    let codeCycle: Double = 3.8 // seconds for the full loop (lower = faster)
    lazy var codeGlyphMasks: [NSImage] = codeGlyphs.map { StatusController.glyphMask($0) }
    let crabFPS: Double = 12.5 // matches the source GIF's 0.08s frame delay
    lazy var crabFrames: [NSImage] = StatusController.decodePNGs(clawdCrabFramePNGs)
    lazy var crabTemplateFrames: [NSImage] = crabFrames.map { adaptiveCrabFrame($0) }

    var markFPS: Double = 15
    var markAdvance: Int { max(1, Int((30.0 / max(1, markFPS)).rounded())) }
    let markOrbitReps = 2
    let markBreatheReps = 4
    let markFadeFrames = 4
    var markDotScale: CGFloat = 1.08
    var markSparkScale: CGFloat = 0.92
    func loadMarkConfig() {
        let cfg = uiConfig()
        markFPS = cfg["markFPS"] ?? 15
        markDotScale = CGFloat(cfg["markDotScale"] ?? 1.08)
        markSparkScale = CGFloat(cfg["markSparkScale"] ?? 0.92)
    }

    lazy var markFrames: [String: [NSImage]] = {
        var out: [String: [NSImage]] = [:]
        for s in workingMarkStrips {
            guard let data = Data(base64Encoded: s.data), let img = NSImage(data: data),
                  let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
            out[s.name] = (0..<s.frames).compactMap { i in
                cg.cropping(to: CGRect(x: 0, y: i * 48, width: 48, height: 48))
                    .map { NSImage(cgImage: $0, size: NSSize(width: 48, height: 48)) }
            }
        }
        return out
    }()

    lazy var markSequence: [(strip: String, frame: Int)] = {
        func n(_ name: String) -> Int { workingMarkStrips.first { $0.name == name }?.frames ?? 0 }
        var seq: [(strip: String, frame: Int)] = []
        for i in 0..<n("en110") { seq.append((strip: "en110", frame: i)) }
        for _ in 0..<markOrbitReps { for i in 0..<n("loop110") { seq.append((strip: "loop110", frame: i)) } }
        for _ in 0..<markBreatheReps { for i in 0..<n("loop40") { seq.append((strip: "loop40", frame: i)) } }
        for i in 0..<n("ex40") { seq.append((strip: "ex40", frame: i)) }
        return seq
    }()
    var markLoopStart: Int { workingMarkStrips.first { $0.name == "en110" }?.frames ?? 0 }
    var markBodyCount: Int { markSequence.count - (workingMarkStrips.first { $0.name == "ex40" }?.frames ?? 0) }

    var fps: Double {
        switch animStyle {
        case .web: return spriteFPS
        case .code: return Double(codeGlyphs.count * codeSub) / codeCycle
        case .crab: return crabFPS
        case .mark: return markFPS
        }
    }
    var frameCount: Int {
        switch animStyle {
        case .web: return max(1, frames.count)
        case .code: return codeGlyphs.count * codeSub
        case .crab: return max(1, crabFrames.count)
        case .mark: return max(1, markBodyCount)
        }
    }
    var loopStart: Int { animStyle == .mark ? markLoopStart : 0 }

    let logoSet: [NSImage] = Data(base64Encoded: claudeLogoPNG).flatMap(NSImage.init(data:)).map { [$0] } ?? []

    override init() {
        super.init()
        let d = UserDefaults.standard
        if d.object(forKey: "showTimer") != nil { showTimer = d.bool(forKey: "showTimer") }
        if d.object(forKey: "iconSystem") != nil { iconSystem = d.bool(forKey: "iconSystem") }
        if d.object(forKey: "showLabel") != nil { showLabel = d.bool(forKey: "showLabel") }
        if d.object(forKey: "soundThreshold") != nil { soundThreshold = d.double(forKey: "soundThreshold") }
        if let s = d.string(forKey: "animStyle"), let st = AnimStyle(rawValue: s) { animStyle = st }
        loadMarkConfig()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        render(label: "", color: iconColor, animate: false, startedAt: 0)
        let t = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
        tick()
        try? FileManager.default.removeItem(atPath: (baseDir as NSString).appendingPathComponent("quit-intent"))
        refreshRows()
    }

    var currentVersion: String { (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0" }

    // MARK: the provider

    // Runs bin/cockpit-bar with args off the main thread and hands stdout back on it. GUI apps launched by
    // `open` carry a bare PATH, and cockpit needs tmux, git and the keychain, so Homebrew's bin is added.
    func provider(_ args: [String], completion: ((Data) -> Void)? = nil) {
        guard !providerPath.isEmpty else { return }
        let path = providerPath
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: path)
            p.arguments = args
            var env = ProcessInfo.processInfo.environment
            let home = NSHomeDirectory()
            env["PATH"] = "\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "/usr/bin:/bin")
            p.environment = env
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = FileHandle.nullDevice
            do { try p.run() } catch { NSLog("CockpitBar: cannot run %@: %@", path, "\(error)"); return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            if let completion = completion { DispatchQueue.main.async { completion(data) } }
        }
    }

    func refreshRows() {
        guard !rowsLoading else { return }
        rowsLoading = true
        rowsDirtyAt = nil
        lastRowsLoad = Date()
        provider(["--json"]) { [weak self] data in
            guard let self = self else { return }
            self.rowsLoading = false
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let list = obj["rows"] as? [[String: Any]] else { return }
            self.rows = list.map(Row.init(json:))
            self.dueCount = (obj["due"] as? NSNumber)?.intValue ?? 0
            self.applyTitle()
        }
    }

    // An action that changes cockpit state (open, snooze, unsnooze) reloads the rows once it has run.
    func act(_ args: [String]) {
        provider(args) { [weak self] _ in self?.refreshRows() }
    }

    // MARK: menu

    func menuWillOpen(_ menu: NSMenu) {
        menuIsOpen = true
    }
    func menuDidClose(_ menu: NSMenu) {
        menuIsOpen = false
        rowMenuItems.removeAll()
    }

    // The row SET only changes on reopen (NSMenu can't add/remove rows reliably mid-track); the open menu's
    // spinners, labels and timers follow the hook files live.
    func refreshOpenMenuRows() {
        for (item, row) in rowMenuItems {
            guard let v = item.view as? SessionRowView else { continue }
            configureRow(v, row)
        }
    }

    // The hook file behind a row: the most recently written of the session ids cockpit says belong to it.
    func activity(for row: Row) -> Session? {
        row.stateIds.compactMap { sessions[$0] }.max { $0.ts < $1.ts }
    }

    func effective(_ s: Session?) -> String {
        guard let s = s else { return "idle" }
        return s.eff.isEmpty ? effectiveState(s, now: Date().timeIntervalSince1970) : s.eff
    }

    // Rows in display order: due, then running with working sessions first, then snoozed, then recent.
    // Hook-tracked sessions cockpit has not indexed yet (nothing typed) are appended to the running group.
    func orderedRows() -> [Row] {
        var covered = Set<String>()
        for r in rows { covered.formUnion(r.stateIds) }
        var all = rows
        for s in sessions.values where !covered.contains(s.id) && s.started {
            all.append(Row(session: s))
        }
        func rank(_ r: Row) -> Int {
            switch effective(activity(for: r)) {
            case "permission": return 0
            case "thinking", "tool": return 1
            default: return 2
            }
        }
        return all.enumerated().sorted { a, b in
            if a.element.group != b.element.group { return a.element.group < b.element.group }
            if a.element.group == 1 {
                let ra = rank(a.element), rb = rank(b.element)
                if ra != rb { return ra < rb }
            }
            return a.offset < b.offset
        }.map { $0.element }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if Date().timeIntervalSince(lastRowsLoad) > 1 { refreshRows() }   // fresh data for the NEXT open
        rowMenuItems.removeAll()
        let width = CGFloat(uiConfig()["boxWidth"] ?? 380)
        let names = [0: "Due", 1: "Running", 2: "Snoozed", 3: "Recent"]
        var section = -1
        let ordered = orderedRows()
        for row in ordered {
            if row.group != section {
                if section >= 0 { menu.addItem(.separator()) }
                menu.addItem(header(names[row.group] ?? ""))
                section = row.group
            }
            let view = SessionRowView(id: row.id, width: width)
            let rid = row.id
            view.onClick = { [weak self] in menu.cancelTracking(); self?.act(["--open", rid]) }
            configureRow(view, row)
            let it = NSMenuItem()
            it.view = view
            it.submenu = submenu(for: row)
            menu.addItem(it)
            rowMenuItems.append((it, row))
        }
        if ordered.isEmpty {
            menu.addItem(header("Sessions"))
            let none = NSMenuItem(title: rows.isEmpty && providerPath.isEmpty ? "No provider path in Info.plist" : "No sessions", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        }
        menu.addItem(.separator())
        let picker = NSMenuItem(title: "Open the picker", action: #selector(openPicker), keyEquivalent: "")
        picker.target = self
        menu.addItem(picker)

        menu.addItem(.separator())
        menu.addItem(header("Options"))
        menu.addItem(toggleRow(title: "Show timer", isOn: showTimer) { [weak self] on in
            self?.showTimer = on
            UserDefaults.standard.set(on, forKey: "showTimer")
            self?.applyTitle()
        })
        menu.addItem(toggleRow(title: "Show text", isOn: showLabel) { [weak self] on in
            self?.showLabel = on
            UserDefaults.standard.set(on, forKey: "showLabel")
            self?.evaluate()
        })

        let animParent = NSMenuItem(title: "Animation", action: nil, keyEquivalent: "")
        let animSub = NSMenu()
        for (style, name) in [(AnimStyle.web, "Spark"), (AnimStyle.code, "Unicode"), (AnimStyle.crab, "Clawd™"), (AnimStyle.mark, "Orbit")] {
            let it = NSMenuItem(title: name, action: #selector(chooseStyle(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = style.rawValue
            it.state = animStyle == style ? .on : .off
            animSub.addItem(it)
        }
        animParent.submenu = animSub
        menu.addItem(animParent)

        let colorParent = NSMenuItem(title: "Color", action: nil, keyEquivalent: "")
        let colorSub = NSMenu()
        for (sys, name) in [(false, "Orange"), (true, "System")] {
            let it = NSMenuItem(title: name, action: #selector(chooseColor(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = sys
            it.state = iconSystem == sys ? .on : .off
            colorSub.addItem(it)
        }
        colorParent.submenu = colorSub
        menu.addItem(colorParent)

        let soundParent = NSMenuItem(title: "Completion Sound", action: nil, keyEquivalent: "")
        let soundSub = NSMenu()
        for (secs, name) in [(0.0, "Off"), (0.1, "Every turn"), (60.0, "1 min+"), (300.0, "5 min+"), (900.0, "15 min+")] {
            let it = NSMenuItem(title: name, action: #selector(chooseSound(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = NSNumber(value: secs)
            it.state = soundThreshold == secs ? .on : .off
            soundSub.addItem(it)
        }
        soundParent.submenu = soundSub
        menu.addItem(soundParent)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Cockpit Bar \(currentVersion)", action: nil, keyEquivalent: ""))
        let q = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        q.target = self
        menu.addItem(q)
    }

    // The per-row flyout: where the session is and when it was used, its snooze, its MRs (click opens the
    // MR), then the actions.
    func submenu(for row: Row) -> NSMenu {
        let sub = NSMenu()
        func info(_ text: String) {
            let it = NSMenuItem(title: text, action: nil, keyEquivalent: "")
            it.isEnabled = false
            sub.addItem(it)
        }
        if row.synthetic {
            info("running, nothing sent yet")
        } else if row.live {
            let session = row.tmux.split(separator: ":").first.map(String.init) ?? ""
            info(row.tmux.isEmpty ? "running, not in tmux" : "running in tmux session \(session)")
        } else {
            info("closed, resumable")
        }
        var whereLine = row.repo
        if !row.branch.isEmpty { whereLine += " · " + row.branch }
        if !whereLine.isEmpty { info(whereLine) }
        if !row.started.isEmpty { info("started " + row.started) }
        if !row.last.isEmpty { info("last prompt " + row.last) }
        if !row.snoozeText.isEmpty { info(row.snoozeText) }
        if !row.wakes.isEmpty { info("wakes on " + row.wakes) }
        // The identifiers: the Jira ticket as a link, then the MRs grouped under the repository they live in,
        // in order of first mention; MR rows are indented under a dimmed repo line and a click opens the MR.
        if !row.ticket.isEmpty {
            sub.addItem(.separator())
            let it = NSMenuItem(title: row.ticket, action: row.ticketURL.isEmpty ? nil : #selector(openURL(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = row.ticketURL
            it.toolTip = row.ticketURL
            it.image = symbolImage("ticket")
            sub.addItem(it)
        }
        if !row.mrs.isEmpty {
            if row.ticket.isEmpty { sub.addItem(.separator()) }
            var projects: [String] = []
            for mr in row.mrs where !projects.contains(mr.project) { projects.append(mr.project) }
            for project in projects {
                let list = row.mrs.filter { $0.project == project }
                let head = NSMenuItem(title: list.first?.repo.isEmpty == false ? list.first!.repo : "merge requests", action: nil, keyEquivalent: "")
                head.isEnabled = false
                head.toolTip = project
                sub.addItem(head)
                for mr in list {
                    var title = "!\(mr.iid)"
                    if !mr.title.isEmpty { title += "  " + truncated(mr.title, max: 46, keep: 44) }
                    let it = NSMenuItem(title: title, action: #selector(openURL(_:)), keyEquivalent: "")
                    it.target = self
                    it.indentationLevel = 1
                    it.representedObject = mr.url
                    it.toolTip = mr.url
                    if !mr.state.isEmpty {
                        // The state sits after the title in the secondary colour, so "merged" and "opened" read at a glance.
                        let text = NSMutableAttributedString(string: title, attributes: [.font: NSFont.menuFont(ofSize: 0), .foregroundColor: NSColor.labelColor])
                        text.append(NSAttributedString(string: "  " + mr.state, attributes: [.font: NSFont.menuFont(ofSize: 0), .foregroundColor: NSColor.secondaryLabelColor]))
                        it.attributedTitle = text
                    }
                    sub.addItem(it)
                }
            }
        }
        sub.addItem(.separator())
        func action(_ title: String, _ args: [String]) {
            let it = NSMenuItem(title: title, action: #selector(runAction(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = args
            sub.addItem(it)
        }
        action("Open", ["--open", row.id])
        if row.synthetic { return sub }
        if row.snoozed {
            action("Unsnooze", ["--unsnooze", row.id])
        } else {
            action("Snooze 2h", ["--snooze", row.id, "2h"])
            action("Snooze until tomorrow", ["--snooze", row.id, "tomorrow"])
            if let mr = row.mrs.first {
                action("Snooze until !\(mr.iid) moves", ["--snooze", row.id, mr.url])
                action("Snooze until !\(mr.iid) merges", ["--snooze", row.id, mr.url, "merge"])
            }
        }
        return sub
    }

    @objc func runAction(_ sender: NSMenuItem) {
        guard let args = sender.representedObject as? [String] else { return }
        act(args)
    }
    @objc func openURL(_ sender: NSMenuItem) {
        guard let s = sender.representedObject as? String, let url = URL(string: s) else { return }
        NSWorkspace.shared.open(url)
    }
    @objc func openPicker() { act(["--picker"]) }

    func header(_ title: String) -> NSMenuItem {
        if #available(macOS 14.0, *) { return NSMenuItem.sectionHeader(title: title) }
        let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        it.isEnabled = false
        return it
    }

    func toggleRow(title: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) -> NSMenuItem {
        let width = CGFloat(uiConfig()["boxWidth"] ?? 380), height: CGFloat = 24, leftInset: CGFloat = 14, rightInset: CGFloat = 12
        let row = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        row.autoresizingMask = [.width]
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.menuFont(ofSize: 0)
        label.textColor = .labelColor
        label.sizeToFit()
        label.setFrameOrigin(NSPoint(x: leftInset, y: (height - label.frame.height) / 2))
        label.autoresizingMask = [.maxXMargin]
        row.addSubview(label)
        let toggle = ToggleView(isOn: isOn)
        toggle.onToggle = onToggle
        toggle.setFrameOrigin(NSPoint(x: width - toggle.frame.width - rightInset, y: (height - toggle.frame.height) / 2))
        toggle.autoresizingMask = [.minXMargin]
        row.addSubview(toggle)
        let item = NSMenuItem()
        item.view = row
        return item
    }

    // Live layout knobs read from ~/.local/state/cockpit/bar/uiconfig.json each render (boxWidth, markFPS, …).
    func uiConfig() -> [String: Double] {
        let p = (baseDir as NSString).appendingPathComponent("uiconfig.json")
        guard let d = FileManager.default.contents(atPath: p),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        return j.compactMapValues { ($0 as? NSNumber)?.doubleValue }
    }

    // [icon] ticket · title <spacer> what it is doing / its snooze ›
    func configureRow(_ v: SessionRowView, _ row: Row) {
        let now = Date().timeIntervalSince1970
        let s = activity(for: row)
        let eff = effective(s)
        let working = (eff == "thinking" || eff == "tool")
        // The row says what the work is: a verb pill (Review, Implement, Design, …) and the subject.
        // Ticket keys and MR numbers live in the flyout, where they are links.
        let primary = row.title
        let secondary = ""
        var trailing: String? = nil
        var trailingColor: NSColor = .secondaryLabelColor
        var icon: NSImage? = nil
        var tint: NSColor? = .tertiaryLabelColor
        if row.due {
            icon = symbolImage("alarm.fill", tint: amber); tint = nil
            trailing = stripGlyph(row.snoozeShort); trailingColor = amber
        } else if eff == "permission" {
            icon = symbolImage("exclamationmark.circle.fill", tint: amber); tint = nil
            trailing = "awaiting permission"; trailingColor = amber
        } else if working, let s = s {
            trailing = workingLabel(s) + (s.startedAt > 0 ? " · " + elapsed(max(0, Int(now - s.startedAt))) : "")
            trailingColor = .labelColor
        } else if row.snoozed {
            icon = symbolImage("moon.zzz.fill"); tint = .tertiaryLabelColor
            trailing = stripGlyph(row.snoozeShort)
        } else if row.live {
            icon = restingCaret; tint = .tertiaryLabelColor
        } else {
            icon = symbolImage("clock"); tint = .quaternaryLabelColor
        }
        v.configure(icon: icon, iconTint: tint, spinning: working, primary: primary, secondary: secondary,
                    pill: row.verb.isEmpty ? nil : pillImage(row.verb), pillSelected: row.verb.isEmpty ? nil : pillImage(row.verb, selected: true),
                    trailing: trailing.map { truncated($0, max: 34, keep: 32) }, trailingColor: trailingColor, gap: 10)
        var tip = (row.verb.isEmpty ? "" : row.verb + " · ") + row.title + (row.ticket.isEmpty ? "" : " · " + row.ticket)
        tip += "\n" + row.repo + (row.branch.isEmpty ? "" : " · " + row.branch)
        if !row.snoozeText.isEmpty { tip += "\n" + row.snoozeText }
        v.toolTip = tip
    }

    // The verb pill, rendered as an image so it sits inside the row text. From upstream's CLI/APP pill.
    func pillImage(_ text: String, selected: Bool = false) -> NSImage {
        let key = "pill|\(text)|\(selected)|\(NSApp.effectiveAppearance.name.rawValue)"
        if let hit = pillCache[key] { return hit }
        let t = text as NSString
        let font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        let pad: CGFloat = 6, h: CGFloat = 16
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let bg = selected ? NSColor.white.withAlphaComponent(0.22)
                          : (dark ? NSColor.white : NSColor.black).withAlphaComponent(dark ? 0.14 : 0.10)
        let fg = selected ? NSColor.white : NSColor.labelColor
        let w = ceil(t.size(withAttributes: [.font: font]).width) + pad * 2
        let img = NSImage(size: NSSize(width: w, height: h), flipped: false) { rect in
            bg.setFill()
            NSBezierPath(roundedRect: rect, xRadius: h / 2, yRadius: h / 2).fill()
            let a: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: fg]
            let ts = t.size(withAttributes: a)
            t.draw(at: NSPoint(x: (rect.width - ts.width) / 2, y: (rect.height - ts.height) / 2 - 0.5), withAttributes: a)
            return true
        }
        pillCache[key] = img
        return img
    }

    // cockpit's snooze text starts with its own glyph (⏾ or ⏰); the row's icon already says that.
    func stripGlyph(_ s: String) -> String {
        var t = s
        for g in ["⏾ ", "⏰ ", "⏾", "⏰"] where t.hasPrefix(g) { t = String(t.dropFirst(g.count)) }
        return t
    }

    func statusText(_ s: Session, eff: String) -> String {
        guard showLabel else { return "" }
        switch eff {
        case "permission":       return "Awaiting permission"
        case "thinking", "tool": return workingLabel(s)
        default:                 return s.state == "done" ? "Done" : "Idle"
        }
    }

    // The shell-style prompt caret (U+276F, what Claude Code shows when idle), dimmed and centered in
    // a square that matches the spinner gutter so the resting rows align with the working ones.
    lazy var restingCaret: NSImage? = {
        let glyph = "\u{276F}" as NSString
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let side: CGFloat = 15
        let img = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
            let g = glyph.size(withAttributes: attrs)
            glyph.draw(at: NSPoint(x: (side - g.width) / 2, y: (side - g.height) / 2), withAttributes: attrs)
            return true
        }
        img.isTemplate = true
        return img
    }()

    func symbolImage(_ name: String, tint: NSColor? = nil) -> NSImage? {
        guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
        if let tint = tint, #available(macOS 12.0, *) {
            return img.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [tint]))
        }
        img.isTemplate = true
        return img
    }

    // Over `max` chars, show the first `keep` + an ellipsis.
    func truncated(_ s: String, max: Int = 20, keep: Int = 18) -> String {
        s.count > max ? String(s.prefix(keep)) + "…" : s
    }

    // Rank a session's EFFECTIVE state for surfacing (higher = more important).
    func priority(of eff: String) -> Int {
        switch eff {
        case "permission":       return 2
        case "thinking", "tool": return 1
        default:                 return 0
        }
    }

    func workingLabel(_ s: Session) -> String {
        if s.state == "thinking" {
            let w = sessionWord[s.id] ?? thinkingWords.randomElement() ?? ""
            if !w.isEmpty { return w + "…" }
        }
        return s.label.isEmpty ? "Working…" : s.label
    }

    // Re-pick a word each time a session ENTERS the thinking state, avoiding an immediate repeat.
    func updateThinkingWord(_ s: Session) {
        let prev = prevState[s.id] ?? ""
        guard s.state == "thinking", prev != "thinking" else { return }
        var w = thinkingWords.randomElement() ?? "Thinking"
        if thinkingWords.count > 1 { while w == sessionWord[s.id] { w = thinkingWords.randomElement() ?? w } }
        sessionWord[s.id] = w
    }

    // "1m 1s" / "43s", Claude Code's elapsed-clock style.
    func elapsed(_ secs: Int) -> String {
        let m = secs / 60, s = secs % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }

    // The marker keeps update.js's self-relaunch from undoing an explicit Quit; cleared on the next
    // SessionStart (lifecycle.js) or the next manual launch, whichever comes first.
    @objc func quit() {
        FileManager.default.createFile(atPath: (baseDir as NSString).appendingPathComponent("quit-intent"), contents: nil)
        NSApp.terminate(nil)
    }

    @objc func chooseColor(_ sender: NSMenuItem) {
        guard let sys = sender.representedObject as? Bool else { return }
        iconSystem = sys
        UserDefaults.standard.set(iconSystem, forKey: "iconSystem")
        iconCache.removeAll()
        evaluate()
    }

    @objc func chooseSound(_ sender: NSMenuItem) {
        guard let n = sender.representedObject as? NSNumber else { return }
        soundThreshold = n.doubleValue
        UserDefaults.standard.set(soundThreshold, forKey: "soundThreshold")
    }

    @objc func chooseStyle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let st = AnimStyle(rawValue: raw) else { return }
        animStyle = st
        UserDefaults.standard.set(raw, forKey: "animStyle")
        iconCache.removeAll()
        loadMarkConfig()
        animTimer?.invalidate(); animTimer = nil
        markOutro = false
        frameIdx = 0
        evaluate()
    }

    // MARK: state polling

    func tick() {
        if reloadSessions() { rowsDirtyAt = rowsDirtyAt ?? Date() }
        evaluate()
        if menuIsOpen { refreshOpenMenuRows() }
        // Rows follow hook-file changes with a short delay (a new session needs a moment to be indexed),
        // and otherwise refresh on a slow cadence so snoozes firing in the wake job show up.
        let now = Date()
        if let dirty = rowsDirtyAt, now.timeIntervalSince(dirty) > 1.5 { refreshRows() }
        else if now.timeIntervalSince(lastRowsLoad) > rowsInterval { refreshRows() }
    }

    func stateFileNames() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: stateDir)) ?? []).filter { $0.hasSuffix(".json") }
    }

    // Refresh `sessions` from state.d/, re-parsing only files whose mtime changed (writes are atomic
    // renames, so a content update bumps mtime and is never read torn). True when anything changed.
    @discardableResult
    func reloadSessions() -> Bool {
        let fm = FileManager.default
        let files = stateFileNames()
        let present = Set(files)
        var changed = false
        for key in Array(fileMTimes.keys) where !present.contains(key) {
            fileMTimes[key] = nil
            sessions[(key as NSString).deletingPathExtension] = nil
            changed = true
        }
        for f in files {
            let full = (stateDir as NSString).appendingPathComponent(f)
            guard let attrs = try? fm.attributesOfItem(atPath: full),
                  let m = attrs[.modificationDate] as? Date else { continue }
            if fileMTimes[f] == m { continue }
            fileMTimes[f] = m
            guard let data = fm.contents(atPath: full),
                  let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let id = (f as NSString).deletingPathExtension
            let wasKnown = sessions[id] != nil
            sessions[id] = Session(json: o, id: id)
            if !wasKnown { changed = true }
        }
        return changed
    }

    // Working->done edge for the completion chime, gated on turn length >= soundThreshold (0 = off).
    func completionEdge(_ s: Session, now: Double) -> Bool {
        if s.state == "thinking" || s.state == "tool", s.startedAt > 0 { turnStart[s.id] = s.startedAt }
        let prev = prevState[s.id] ?? ""
        var edge = false
        if soundThreshold > 0, s.state == "done", prev != "done", let st = turnStart[s.id], st > 0, now - st >= soundThreshold { edge = true }
        if s.state == "done" { turnStart[s.id] = 0 }
        return edge
    }

    func evaluate() {
        let now = Date().timeIntervalSince1970
        var chime = false

        for id in Array(sessions.keys) {
            guard var s = sessions[id] else { continue }
            s.eff = effectiveState(s, now: now)
            // Reap on PROCESS death: a session leaves only when its `claude` process is gone. Files without
            // a pid fall back to an idle-age prune so they cannot linger forever.
            let dead = s.pid > 0 ? !pidAlive(s.pid) : (s.eff == "idle" && now - s.ts > 900)
            if dead {
                try? FileManager.default.removeItem(atPath: (stateDir as NSString).appendingPathComponent(id + ".json"))
                sessions[id] = nil; fileMTimes[id + ".json"] = nil; prevState[id] = nil; sessionWord[id] = nil; turnStart[id] = nil
                rowsDirtyAt = rowsDirtyAt ?? Date()
                continue
            }
            sessions[id] = s
            updateThinkingWord(s)
            if completionEdge(s, now: now) { chime = true }
            prevState[s.id] = s.state
        }
        for id in Array(prevState.keys) where sessions[id] == nil { prevState[id] = nil; sessionWord[id] = nil; turnStart[id] = nil }
        if chime { completionSound?.play() }

        // Surface the single highest-priority session (permission > working > …); ties broken by recency.
        let lead = sessions.values.max { a, b in
            let pa = priority(of: a.eff), pb = priority(of: b.eff)
            return pa == pb ? a.ts < b.ts : pa < pb
        }
        statusItem.button?.toolTip = lead.map { statusText($0, eff: $0.eff) + (dueCount > 0 ? " · \(dueCount) due" : "") }

        guard let lead = lead else { renderResting(); return }
        switch lead.eff {
        case "permission":
            render(label: statusText(lead, eff: lead.eff), color: amber, animate: false, startedAt: 0, dot: true)
        case "thinking", "tool":
            render(label: statusText(lead, eff: lead.eff), color: iconColor, animate: true, startedAt: lead.startedAt)
        default:
            renderResting()
        }
    }

    func renderResting() { render(label: "", color: iconColor, animate: false, startedAt: 0) }

    // Transcripts only grow when text streams, so gate the tail read on mtime.
    func cachedLastTurnLine(_ path: String) -> String? {
        let m = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
        if let hit = turnLineCache[path], hit.mtime == m { return hit.line }
        let line = lastTurnLine(ofFileAt: path)
        turnLineCache[path] = (m, line)
        return line
    }

    // Per-session effective state with two recovery nets: an absolute age cap, plus the transcript
    // "interrupted by user" marker (Esc / denied permission fire no hook, freezing the file).
    func effectiveState(_ s: Session, now: Double) -> String {
        if s.state == "thinking" || s.state == "tool" || s.state == "permission" {
            let cap: Double = s.state == "permission" ? 7200 : 900
            if now - s.ts > cap { return "idle" }
            if !s.transcript.isEmpty, let last = cachedLastTurnLine(s.transcript),
               last.contains("interrupted by user") { return "idle" }
            return s.state
        }
        return s.state == "done" ? "idle" : s.state
    }

    // kill(pid,0) returns 0 if the process exists; EPERM = exists but not ours; ESRCH = gone.
    func pidAlive(_ pid: Int32) -> Bool {
        if pid <= 0 { return false }
        return kill(pid, 0) == 0 || errno == EPERM
    }

    // Last actual turn line (a user/assistant message), ignoring the bookkeeping lines Claude Code
    // appends after an interrupt, which would otherwise hide the "interrupted by user" marker.
    func lastTurnLine(ofFileAt path: String) -> String? {
        guard let fh = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? fh.close() }
        let size = (try? fh.seekToEnd()) ?? 0
        let chunk: UInt64 = 8192
        try? fh.seek(toOffset: size > chunk ? size - chunk : 0)
        guard let data = try? fh.readToEnd(), let s = String(data: data, encoding: .utf8) else { return nil }
        return s.split(separator: "\n").last {
            $0.contains("\"type\":\"user\"") || $0.contains("\"type\":\"assistant\"")
        }.map(String.init)
    }

    // MARK: render

    func render(label: String, color: NSColor?, animate: Bool, startedAt: Double, dot: Bool = false) {
        guard let button = statusItem.button else { return }
        button.contentTintColor = nil
        activeBase = label
        activeColor = color
        self.startedAt = startedAt

        if animate {
            markOutro = false
            if animTimer == nil {
                let t = Timer(timeInterval: 1.0 / fps, repeats: true) { [weak self] _ in self?.animStep() }
                RunLoop.main.add(t, forMode: .common)
                animTimer = t
            }
        } else if dot {
            markOutro = false
            animTimer?.invalidate(); animTimer = nil
            frameIdx = 0
            button.image = dotIcon(color: color)
        } else if markOutro {
            ()
        } else if animStyle == .mark, animTimer != nil, frameIdx >= markLoopStart {
            markOutro = true
            frameIdx = markBodyCount
        } else {
            animTimer?.invalidate(); animTimer = nil
            frameIdx = 0
            button.image = restingIcon(color: color)
        }
        applyTitle()
        if button.image == nil { button.image = dot ? dotIcon(color: color) : restingIcon(color: color) }
    }

    func animStep() {
        frameIdx += (animStyle == .mark ? markAdvance : 1)
        if markOutro {
            if frameIdx >= markSequence.count - 1 {
                markOutro = false
                animTimer?.invalidate(); animTimer = nil
                frameIdx = 0
                statusItem.button?.image = restingIcon(color: activeColor)
                applyTitle()
                return
            }
        } else if frameIdx >= frameCount {
            let body = max(1, frameCount - loopStart)
            frameIdx = loopStart + (frameIdx - loopStart) % body
        }
        statusItem.button?.image = iconImage(color: activeColor, frame: frameIdx)
        applyTitle()
    }

    // The title is the lead session's label, the elapsed clock when enabled, and the due-snooze count.
    func applyTitle() {
        guard let button = statusItem.button else { return }
        var text = activeBase
        if showTimer, startedAt > 0 {
            let clock = elapsed(max(0, Int(Date().timeIntervalSince1970 - startedAt)))
            text = text.isEmpty ? clock : text + "  " + clock
        }
        if dueCount > 0 { text += (text.isEmpty ? "" : "  ") + "⏰ \(dueCount)" }
        // Assigning attributedTitle re-snapshots the status item bitmap, so skip it when unchanged.
        guard text != lastTitleText else { return }
        lastTitleText = text
        if text.isEmpty {
            button.imagePosition = .imageOnly
            button.attributedTitle = NSAttributedString(string: "")
            return
        }
        button.imagePosition = .imageLeading
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular),
        ]
        button.attributedTitle = NSAttributedString(string: " \(text)", attributes: attrs)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = StatusController()
app.run()
