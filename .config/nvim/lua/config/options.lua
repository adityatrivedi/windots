-- Core, safe editor options
local o = vim.opt

-- UI
o.number = true
o.relativenumber = true
o.signcolumn = 'yes'
o.cursorline = true
o.termguicolors = true
o.showmode = false
o.fillchars = { eob = ' ' }

-- Wrapping
o.wrap = true
o.linebreak = true
o.breakindent = true

-- Scrolling
o.scrolloff = 8
o.sidescrolloff = 8

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
o.inccommand = 'split'

-- File handling
o.undofile = true
o.swapfile = false
o.backup = false
o.hidden = true

-- Behavior
o.updatetime = 300
o.timeoutlen = 400
o.splitright = true
o.splitbelow = true
o.mouse = 'a'
o.clipboard = 'unnamedplus'
o.completeopt = { 'menu', 'menuone', 'noselect' }
