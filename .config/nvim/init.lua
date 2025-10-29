-- core options
require('config.options')

-- keymaps: VS Code vs standalone
if vim.g.vscode then
  require('config.vscode')
else
  require('config.keymaps')
end
