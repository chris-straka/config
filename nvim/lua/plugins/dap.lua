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
      { '<leader>dO', function() require('dap').step_out() end, desc = 'Step out' },
      { '<leader>dq', function() require('dap').terminate() end, desc = 'Stop debugging' },
      {
        '<leader>dr',
        function()
          local repl = require('dap').repl
          -- close() reports whether it shut anything: on shut, focus falls
          -- back to the code by itself. On open, upstream deliberately
          -- leaves focus in the code, so move in and start typing — zero
          -- window commands either way.
          if repl.close() then return end
          repl.open()
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == 'dap-repl' then
              vim.api.nvim_set_current_win(win)
              local last = vim.api.nvim_buf_line_count(buf)
              local len = #vim.api.nvim_buf_get_lines(buf, last - 1, last, false)[1]
              vim.api.nvim_win_set_cursor(win, { last, len })
              vim.cmd('startinsert')
              return
            end
          end
        end,
        desc = 'Toggle REPL',
      },
      { '<leader>dR', function() require('dap').restart() end, desc = 'Restart session' },
    },
    config = function()
      local dap = require('dap')
      -- Python without a launch.json: dc runs the current file through
      -- mason's debugpy. env is a function (nvim-dap evaluates config
      -- functions at launch), so leetcode files get the same PYTHONPATH
      -- the <leader>of runner sets (see config/runner.lua).
      dap.adapters.python = {
        type = 'executable',
        command = vim.fn.stdpath('data') .. '/mason/packages/debugpy/venv/bin/python',
        args = { '-m', 'debugpy.adapter' },
      }
      -- Same adapter under its protocol name: configs say type debugpy
      -- (launch.json convention) and nvim-dap looks adapters up by it.
      dap.adapters.debugpy = dap.adapters.python
      dap.configurations.python = {
        {
          type = 'python',
          request = 'launch',
          name = 'Launch file',
          program = '${file}',
          env = function()
            local lcdir = require('config.runner').leetcode_dir(vim.api.nvim_buf_get_name(0))
            if lcdir then return { PYTHONPATH = lcdir } end
            return nil
          end,
        },
      }
    end,
  },
  -- Toggle-only on purpose (no auto-open listeners): nothing pops open
  -- unasked mid-session; du brings the panels up when wanted.
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
  {
    'leoluz/nvim-dap-go',
    ft = 'go',
    dependencies = { 'mfussenegger/nvim-dap' },
    config = function() require('dap-go').setup() end,
  },
}
