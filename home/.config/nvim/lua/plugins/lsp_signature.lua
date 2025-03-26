return {
  "ray-x/lsp_signature.nvim",
  enabled = false,
  event = "InsertEnter",
  opts = {
    bind = true,         -- This is mandatory, otherwise border config won't get registered.
    handler_opts = {
      border = "rounded" -- double, rounded, single, shadow, none
    },
  },
  config = function(_, opts) require 'lsp_signature'.setup(opts) end
}
