-- Testing: in-file test runner (neotest) + run-selection scratchpad (sniprun).
-- Adapters match this machine's real test setups: cargo test everywhere,
-- pytest in the Python projects, vitest in ccez-llm, go test for Go.
-- (bun test / node --test / hardhat projects have no neotest adapter —
-- run those with the file runner <leader>of or a task <leader>or.)
return {
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-neotest/nvim-nio',
      'nvim-treesitter/nvim-treesitter',
      -- Test output routes through overseer (consumers.overseer is
      -- required in config below), so it must load first: without this,
      -- the first <leader>Tr on a fresh start throws module-not-found.
      'stevearc/overseer.nvim',
      'nvim-neotest/neotest-python',
      'rouge8/neotest-rust',
      'marilari88/neotest-vitest',
      'fredrikaverpil/neotest-golang',
    },
    config = function()
      require('neotest').setup({
        adapters = {
          require('neotest-python'),
          require('neotest-rust'),
          require('neotest-vitest'),
          require('neotest-golang'),
        },
        -- Route test runs through overseer so results land in the task
        -- list (<leader>ot) next to every other run output. (Documented in
        -- overseer's third_party.md; drop this block if it ever errors and
        -- neotest falls back to its own output panel.)
        consumers = {
          overseer = require('neotest.consumers.overseer'),
        },
      })
    end,
    keys = {
      { '<leader>Tr', function() require('neotest').run.run() end, desc = 'Test nearest' },
      { '<leader>Tf', function() require('neotest').run.run(vim.fn.expand('%')) end, desc = 'Test file' },
      { '<leader>Ta', function() require('neotest').run.run(vim.fn.getcwd()) end, desc = 'Test all (cwd)' },
      { '<leader>Td', function() require('neotest').run.run({ strategy = 'dap' }) end, desc = 'Debug nearest test' },
      { '<leader>To', function() require('neotest').output_panel.toggle() end, desc = 'Test output panel' },
      { '<leader>Ts', function() require('neotest').summary.toggle() end, desc = 'Test summary' },
      { '<leader>Tx', function() require('neotest').run.stop() end, desc = 'Stop test' },
    },
  },
  {
    -- Scratchpad: visual-select code, run just that chunk, result appears
    -- as virtual text at the line. Interpreters stay alive (Python REPL),
    -- so variables persist between runs.
    'michaelb/sniprun',
    branch = 'master',
    build = 'sh install.sh',
    keys = {
      { '<leader>sr', '<Plug>SnipRun', mode = 'v', desc = 'Run selection' },
      { '<leader>sr', '<Plug>SnipRunOperator', mode = 'n', desc = 'Run operator' },
      { '<leader>sc', '<Plug>SnipClose', mode = 'n', desc = 'Clear sniprun' },
    },
    opts = {
      display = { 'VirtualTextOk', 'VirtualTextErr', 'TempFloatingWindow' },
    },
  },
}
