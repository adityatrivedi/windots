-- bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- core options
require('config.options')

-- plugins (auto-imported from lua/plugins/)
require('lazy').setup('plugins')

-- keymaps: VS Code vs standalone
if vim.g.vscode then
  require('config.vscode')
else
  require('config.keymaps')
end
