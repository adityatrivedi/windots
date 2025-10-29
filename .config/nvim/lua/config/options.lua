-- Core, safe editor options
local o = vim.opt

-- UI
o.number = true
o.relativenumber = true
o.signcolumn = 'yes'
o.cursorline = true
o.wrap = false
o.termguicolors = true

-- Tabs/indent
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.smartindent = true

-- Search
o.ignorecase = true
o.smartcase = true
o.incsearch = true
o.hlsearch = true

-- Behavior
o.updatetime = 300
o.timeoutlen = 400
o.splitright = true
o.splitbelow = true
o.mouse = 'a'
o.clipboard = 'unnamedplus' -- Use system clipboard
