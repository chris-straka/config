-- Debugging: plugins were installed but had no adapters and no keymaps,
-- so nothing was actually debuggable. Adapters come from mason (see the
-- mason-tool-installer list in lsp.lua); the keys below drive them.
return {
  {
    'mfussenegger/nvim-dap',
    cmd = { 'DapToggleBreakpoint', 'DapContinue' },
    keys = {
      { '<leader>db', function() require('dap').toggle_breakpoint() end, desc = 'Toggle breakpoint' },
      { '<leader>dc', function() require('dap').continue() end, desc = 'Continue' },
      { '<leader>do', function() require('dap').step_over() end, desc = 'Step over' },
      { '<leader>di', function() require('dap').step_into() end, desc = 'Step into' },
    },
  },
  {
    'rcarriga/nvim-dap-ui',
    dependencies = { 'mfussenegger/nvim-dap', 'nvim-neotest/nvim-nio' },
    keys = {
      { '<leader>du', function() require('dapui').toggle() end, desc = 'Toggle debug UI' },
    },
    config = function() require('dapui').setup() end,
  },
  { 'theHamsta/nvim-dap-virtual-text', opts = {} },
  -- Go debugging: wires the ~/go/bin/dlv binary into nvim-dap with
  -- standard launch configs. No mason package (see GOBIN note in lsp.lua).
  { 'leoluz/nvim-dap-go', ft = 'go', dependencies = { 'mfussenegger/nvim-dap' },
    config = function() require('dap-go').setup() end },
}
