-- Standalone Neovim keymaps
local map = vim.keymap.set
vim.keymap.set("", "<Space>", "<Nop>")

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

-- Window management (<leader>s prefix: "s" for split)
-- Navigation mirrors the j/k/l/; movement layout above
map('n', '<leader>sj', '<C-w>h', { silent = true, desc = 'Focus window left' })
map('n', '<leader>sk', '<C-w>j', { silent = true, desc = 'Focus window down' })
map('n', '<leader>sl', '<C-w>k', { silent = true, desc = 'Focus window up' })
map('n', '<leader>s;', '<C-w>l', { silent = true, desc = 'Focus window right' })

map('n', '<leader>sv', '<Cmd>vsplit<CR>', { silent = true, desc = 'Split vertical' })
map('n', '<leader>sh', '<Cmd>split<CR>',  { silent = true, desc = 'Split horizontal' })
map('n', '<leader>sx', '<Cmd>close<CR>',  { silent = true, desc = 'Close window' })
map('n', '<leader>so', '<Cmd>only<CR>',   { silent = true, desc = 'Close other windows' })
map('n', '<leader>se', '<C-w>=',          { silent = true, desc = 'Equalize windows' })

-- Resize focused window
map('n', '<C-Up>',    '<Cmd>resize +2<CR>',          { silent = true, desc = 'Increase window height' })
map('n', '<C-Down>',  '<Cmd>resize -2<CR>',          { silent = true, desc = 'Decrease window height' })
map('n', '<C-Left>',  '<Cmd>vertical resize -2<CR>', { silent = true, desc = 'Decrease window width' })
map('n', '<C-Right>', '<Cmd>vertical resize +2<CR>', { silent = true, desc = 'Increase window width' })
