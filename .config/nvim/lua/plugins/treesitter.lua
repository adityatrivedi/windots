return {
  'nvim-treesitter/nvim-treesitter',
  -- Pin to the classic, stable branch. The default `main` branch is the
  -- in-progress rewrite and drops the legacy `parsers.ft_to_lang` API that
  -- telescope.nvim (and many other plugins) still rely on.
  branch = 'master',
  build = ':TSUpdate',
  event = { 'BufReadPost', 'BufNewFile' },
  opts = {
    ensure_installed = {
      -- dotfiles / config languages
      'lua',
      'vim',
      'vimdoc',
      'query', -- treesitter query files
      'json',
      'toml',
      'yaml',
      'markdown',
      'markdown_inline',

      -- programming (edit to match your stack)
      'python',
      'javascript',
      'typescript',
      'tsx',
      'bash',
      'c_sharp',
      'powershell',
      'html',
      'css',

      -- misc
      'regex',
      'diff',
      'gitcommit',
      'gitignore',
    },
    highlight = {
      enable = true,
    },
    indent = {
      enable = true,
    },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = '<C-space>',
        node_incremental = '<C-space>',
        scope_incremental = false,
        node_decremental = '<BS>',
      },
    },
  },
  config = function(_, opts)
    -- Prefer zig as the C compiler for parser builds. It's the smallest, most
    -- portable option on Windows and is installed via the winget manifest.
    require('nvim-treesitter.install').compilers = { 'zig' }
    require('nvim-treesitter.configs').setup(opts)
  end,
}
