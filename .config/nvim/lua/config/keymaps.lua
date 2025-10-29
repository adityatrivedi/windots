-- Standalone Neovim keymaps
local map = vim.keymap.set
vim.keymap.set("", "<Space>", "<Nop>")
vim.g.mapleader = ' '

-- Replace hjkl navigation with j k l ;
-- Map: j->left, k->down, l->up, ;->right across normal/visual/operator-pending
map({'n','x','o'}, 'j', 'h', { desc = 'Left' })
map({'n','x','o'}, 'k', 'j', { desc = 'Down' })
map({'n','x','o'}, 'l', 'k', { desc = 'Up' })
map({'n','x','o'}, ';', 'l', { desc = 'Right' })
map({'n','x','o'}, '\'', ';', { desc = 'Repeat previous movement' })

-- Common actions
map('n', '<leader>w', '<Cmd>write<CR>', { silent = true, desc = 'Write' })
map('n', '<leader>q', '<Cmd>quit<CR>',  { silent = true, desc = 'Quit' })

map('n', '<leader>h', '<Cmd>nohlsearch<CR>', { silent = true, desc = 'Clear search' })

-- Clipboard behavior
map('v', 'p', 'P', { silent = true, desc = 'Paste from clipboard' })
