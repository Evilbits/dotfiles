# dotfiles
My usual setup. Note that the Arch setup is in a separate folder and does not have an automatic setup script.

![Arch setup](https://github.com/evilbits/dotfiles/blob/master/pictures/arch.png?raw=true)

## Installation

Install Cascadia Code font.
```sh
$ sudo apt-get install fonts-cascadia-code -y
$ sudo fc-cache -fv
```

To install the dotfiles simply run the linker.
```sh
$ ./linker.sh
```

## Arch installation
The Arch installation is currently hosted in a separate folder and requires manual setup. The configuration within `arch/` can be symlinked into the required locations (depending on the application).

**Required applications:**
* [Dunst](https://wiki.archlinux.org/title/Dunst) - Notifications.
* [Polybar](https://wiki.archlinux.org/title/Polybar) - Status bar.
* [Rofi](https://wiki.archlinux.org/title/Rofi) - Launching applications and navigating to applications.
* [Picom](https://aur.archlinux.org/packages/picom-ibhagwan-git) - (Note this is the ibhagwan fork) Compositor used for window transparency and borders.
* [i3 gaps](https://archlinux.org/packages/community/x86_64/i3-gaps/) - Tiling manager.
* [xorg](https://wiki.archlinux.org/title/xorg) - Display server.
