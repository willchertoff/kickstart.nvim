-- lua/plugins/neotest-jest.lua
--   -- Make a plain Lua table copy of the environment (vim.env is safe, but copy it)
local function copy_env()
  local out = {}
  for k, v in pairs(vim.env) do
    out[k] = v
  end
  return out
end

return {
  {
    'nvim-neotest/neotest',
    ft = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'python' },
    dependencies = {
      'haydenmeade/neotest-jest',
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
      'nvim-neotest/nvim-nio',
      'nvim-neotest/neotest-python',
    },
    keys = {
      {
        '<leader>tn',
        function()
          require('neotest').run.run()
        end,
        desc = 'Run nearest test',
      },
      {
        '<leader>tf',
        function()
          require('neotest').run.run(vim.fn.expand '%')
        end,
        desc = 'Run file',
      },
      {
        '<leader>ts',
        function()
          require('neotest').run.run { suite = true }
        end,
        desc = 'Run suite',
      },
      {
        '<leader>tl',
        function()
          require('neotest').run.run_last()
        end,
        desc = 'Re-run last',
      },
      {
        '<leader>tw',
        function()
          require('neotest').watch.toggle(vim.fn.expand '%')
        end,
        desc = 'Watch file',
      },
      {
        '<leader>to',
        function()
          require('neotest').output.open { enter = true, auto_close = true }
        end,
        desc = 'Open output',
      },
      {
        '<leader>tp',
        function()
          require('neotest').summary.toggle()
        end,
        desc = 'Toggle summary',
      },
      {
        '<leader>tS',
        function()
          require('neotest').run.stop()
        end,
        desc = 'Stop tests',
      },
    },
    opts = function()
      local uv = vim.uv or vim.loop

      local function file_exists(p)
        local s = uv.fs_stat(p)
        return s and s.type == 'file'
      end

      local function join(...)
        return table.concat({ ... }, '/')
      end

      -- Normalize neotest "position" nodes or strings into absolute paths
      local function to_path(file_or_pos)
        if type(file_or_pos) == 'table' then
          if file_or_pos.path then
            return vim.fn.fnamemodify(file_or_pos.path, ':p')
          end
          if file_or_pos.data and file_or_pos.data.path then
            return vim.fn.fnamemodify(file_or_pos.data.path, ':p')
          end
        elseif type(file_or_pos) == 'string' and file_or_pos ~= '' then
          return vim.fn.fnamemodify(file_or_pos, ':p')
        end
        return vim.fn.expand '%:p'
      end

      local function find_project_root(startpath)
        local dir = vim.fn.fnamemodify(startpath or vim.fn.getcwd(), ':p'):gsub('\\', '/')
        while dir and dir ~= '' do
          if file_exists(join(dir, 'package.json')) then
            return dir
          end
          local parent = dir:match '(.+)/[^/]+/?$'
          if not parent or parent == dir then
            break
          end
          dir = parent
        end
        return vim.fn.getcwd()
      end

      local function jest_cmd(cwd)
        local candidates = {
          join(cwd, 'node_modules/.bin/jest'),
          join(cwd, 'node_modules/jest/bin/jest.js'),
        }
        for _, p in ipairs(candidates) do
          if file_exists(p) then
            return p
          end
        end
        return 'jest'
      end

      local function jest_config_for(any)
        local abs = to_path(any)
        local root = find_project_root(vim.fn.fnamemodify(abs, ':h'))
        local configs = {
          'jest.config.ts',
          'jest.config.js',
          'jest.config.cjs',
          'jest.config.mjs',
          'jest.config.json',
          'tests/jest.config.ts',
          'tests/jest.config.js',
        }
        for _, cfg in ipairs(configs) do
          local p = join(root, cfg)
          if file_exists(p) then
            return p
          end
        end
        return nil
      end

      return {
        adapters = {
          require 'neotest-jest' {
            jestCommand = function(any)
              local abs = to_path(any)
              local cwd = find_project_root(vim.fn.fnamemodify(abs, ':h'))
              return jest_cmd(cwd)
            end,
            jestConfigFile = function(any)
              return jest_config_for(any)
            end,
            env = function(any)
              local env = copy_env()
              env.CI = 'true'
              -- add more here if you need (no vim.fn calls)
              return env
            end,
            cwd = function(any)
              local abs = to_path(any)
              return find_project_root(vim.fn.fnamemodify(abs, ':h'))
            end,
          },
          require 'neotest-python' {
            dap = { justMyCode = false }, -- optional debugging config
            args = { '--maxfail=1', '--disable-warnings' }, -- pytest args
            runner = 'pytest',
          },
        },
        run = { strategy = 'integrated' },
        output = { open_on_run = 'short' },
      }
    end,
    config = function(_, opts)
      require('neotest').setup(opts)
    end,
  },
}
