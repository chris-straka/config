-- Merged over the '*' defaults in lua/plugins/lsp.lua when enabled.
return {
  settings = {
    Lua = {
      diagnostics = { globals = { 'vim' } },
      telemetry = { enable = false },
    },
  },
}
