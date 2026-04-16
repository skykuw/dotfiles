-- ~/.config/nvim/init.lua
-- Kickstart-style single-file entry point. Plugin specs live in lua/plugins/.
-- Read top-to-bottom.

--------------------------------------------------------------------------------
-- 1. Leader key (set BEFORE plugins load so mappings bind correctly)
--------------------------------------------------------------------------------
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

--------------------------------------------------------------------------------
-- 2. Options
--------------------------------------------------------------------------------
local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.mouse = 'a'
opt.showmode = false         -- lualine shows mode
opt.clipboard = 'unnamedplus'
opt.breakindent = true
opt.undofile = true
opt.ignorecase = true
opt.smartcase = true
opt.signcolumn = 'yes'
opt.updatetime = 250
opt.timeoutlen = 300
opt.splitright = true
opt.splitbelow = true
opt.list = true
opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
opt.inccommand = 'split'
opt.cursorline = true
opt.scrolloff = 10
opt.termguicolors = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true
opt.wrap = false
opt.confirm = true

-- Per-language indent overrides
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'python', 'go', 'rust', 'c', 'cpp' },
  callback = function() vim.bo.shiftwidth = 4; vim.bo.tabstop = 4; vim.bo.softtabstop = 4 end,
})
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'go',
  callback = function() vim.bo.expandtab = false end,
})

--------------------------------------------------------------------------------
-- 3. Core keymaps (plugin-specific maps live in lua/plugins/)
--------------------------------------------------------------------------------
local map = vim.keymap.set

map('n', '<Esc>', '<cmd>nohlsearch<CR>')
map('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Diagnostics to loclist' })

-- Easier window navigation
map('n', '<C-h>', '<C-w>h', { desc = 'Move focus left' })
map('n', '<C-l>', '<C-w>l', { desc = 'Move focus right' })
map('n', '<C-j>', '<C-w>j', { desc = 'Move focus down' })
map('n', '<C-k>', '<C-w>k', { desc = 'Move focus up' })

-- Highlight yanked text briefly
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function() vim.highlight.on_yank() end,
})

--------------------------------------------------------------------------------
-- 4. Bootstrap lazy.nvim
--------------------------------------------------------------------------------
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({
    'git', 'clone', '--filter=blob:none', '--branch=stable',
    'https://github.com/folke/lazy.nvim.git', lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup('plugins', {
  change_detection = { notify = false },
})
