return {
  'nvim-treesitter/nvim-treesitter',
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
    require('nvim-treesitter.configs').setup(opts)
  end,
}
