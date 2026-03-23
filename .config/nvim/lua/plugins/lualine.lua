return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  event = 'VeryLazy',
  opts = {
    options = {
      theme = 'auto',
      icons_enabled = true,
      section_separators = { left = '', right = '' },
      component_separators = { left = '', right = '' },
      globalstatus = false,
    },
    sections = {
      lualine_a = { 'mode' },
      lualine_b = { 'branch', 'diff' },
      lualine_c = { { 'filename', path = 1 } },
      lualine_x = { 'diagnostics' },
      lualine_y = { 'filetype', 'encoding' },
      lualine_z = { 'location', 'progress' },
    },
    inactive_sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = { { 'filename', path = 1 } },
      lualine_x = { 'location' },
      lualine_y = {},
      lualine_z = {},
    },
  },
}

