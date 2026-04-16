-- Plugin specs loaded by lazy.nvim from lua/plugins/
-- Each table is a plugin; keep related config inline so the full story per plugin is in one place.

return {
  --------------------------------------------------------------------------------
  -- Colorschemes (both installed; catppuccin is the default)
  --------------------------------------------------------------------------------
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    config = function()
      require('catppuccin').setup({
        flavour = 'mocha',
        integrations = { cmp = true, gitsigns = true, nvimtree = true, treesitter = true, telescope = true },
      })
      vim.cmd.colorscheme('catppuccin')
    end,
  },
  { 'folke/tokyonight.nvim', priority = 900, lazy = false },

  --------------------------------------------------------------------------------
  -- UI: statusline, icons, which-key, git signs
  --------------------------------------------------------------------------------
  { 'nvim-tree/nvim-web-devicons', lazy = true },
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      -- 'auto' derives colors from the active colorscheme — works for catppuccin,
      -- tokyonight, or anything else without needing a per-theme module.
      require('lualine').setup({ options = { theme = 'auto', globalstatus = true } })
    end,
  },
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {},
  },
  {
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = { add = { text = '+' }, change = { text = '~' }, delete = { text = '_' } },
    },
  },

  --------------------------------------------------------------------------------
  -- File explorer & fuzzy finder
  --------------------------------------------------------------------------------
  {
    'nvim-tree/nvim-tree.lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('nvim-tree').setup({ view = { width = 32 } })
      vim.keymap.set('n', '<leader>e', '<cmd>NvimTreeToggle<CR>', { desc = 'Toggle file tree' })
    end,
  },
  {
    'nvim-telescope/telescope.nvim',
    branch = '0.1.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make', cond = vim.fn.executable('make') == 1 },
    },
    config = function()
      local t = require('telescope')
      t.setup({})
      pcall(t.load_extension, 'fzf')
      local b = require('telescope.builtin')
      vim.keymap.set('n', '<leader>ff', b.find_files, { desc = 'Find files' })
      vim.keymap.set('n', '<leader>fg', b.live_grep, { desc = 'Live grep' })
      vim.keymap.set('n', '<leader>fb', b.buffers,   { desc = 'Find buffers' })
      vim.keymap.set('n', '<leader>fh', b.help_tags, { desc = 'Find help' })
      vim.keymap.set('n', '<leader>fd', b.diagnostics,{ desc = 'Find diagnostics' })
      vim.keymap.set('n', '<leader>fr', b.resume,    { desc = 'Resume last picker' })
    end,
  },

  --------------------------------------------------------------------------------
  -- Editing ergonomics
  --------------------------------------------------------------------------------
  { 'numToStr/Comment.nvim', opts = {} },
  { 'windwp/nvim-autopairs', event = 'InsertEnter', opts = {} },

  --------------------------------------------------------------------------------
  -- Treesitter (syntax + better highlights / indent / text objects)
  --------------------------------------------------------------------------------
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'master', -- pin to legacy API; the `main` branch rewrite is still in flux
    build = ':TSUpdate',
    main = 'nvim-treesitter.configs',
    opts = {
      ensure_installed = {
        'bash', 'c', 'cpp', 'go', 'gomod', 'gosum', 'lua', 'luadoc',
        'python', 'rust', 'toml', 'json', 'yaml', 'markdown', 'markdown_inline', 'vim', 'vimdoc',
      },
      auto_install = true,
      highlight = { enable = true },
      indent = { enable = true },
    },
  },

  --------------------------------------------------------------------------------
  -- LSP via mason + lspconfig + mason-lspconfig (auto-install servers)
  --------------------------------------------------------------------------------
  {
    'williamboman/mason.nvim',
    cmd = 'Mason',
    opts = {},
  },
  {
    'williamboman/mason-lspconfig.nvim',
    dependencies = { 'williamboman/mason.nvim', 'neovim/nvim-lspconfig' },
    opts = {
      ensure_installed = { 'pylsp', 'gopls', 'rust_analyzer', 'lua_ls', 'clangd' },
      automatic_enable = true, -- nvim 0.11+: auto-calls vim.lsp.enable for installed servers
    },
  },
  {
    'neovim/nvim-lspconfig',
    dependencies = { 'hrsh7th/cmp-nvim-lsp' },
    config = function()
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      -- Apply LSP capabilities to all servers (uses the modern vim.lsp.config API)
      vim.lsp.config('*', { capabilities = capabilities })

      -- Per-server overrides; nvim-lspconfig ships defaults in its lsp/ dir
      -- which vim.lsp.config picks up automatically — these merge on top.
      vim.lsp.config('gopls', {
        settings = { gopls = { analyses = { unusedparams = true }, staticcheck = true } },
      })
      vim.lsp.config('rust_analyzer', {
        settings = { ['rust-analyzer'] = { checkOnSave = { command = 'clippy' } } },
      })
      vim.lsp.config('lua_ls', {
        settings = { Lua = { diagnostics = { globals = { 'vim' } }, workspace = { checkThirdParty = false } } },
      })

      -- Enable servers (mason-lspconfig.automatic_enable also covers mason-installed
      -- ones; this is harmless if duplicated, and covers system-installed servers too).
      vim.lsp.enable({ 'pylsp', 'gopls', 'rust_analyzer', 'lua_ls', 'clangd' })

      -- Buffer-local keymaps that only apply once an LSP attaches
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local bufnr = args.buf
          local opts = function(desc) return { buffer = bufnr, desc = desc } end
          vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts('Go to definition'))
          vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts('References'))
          vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts('Go to implementation'))
          vim.keymap.set('n', 'K',  vim.lsp.buf.hover, opts('Hover docs'))
          vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts('Rename symbol'))
          vim.keymap.set({ 'n', 'x' }, '<leader>ca', vim.lsp.buf.code_action, opts('Code action'))
          vim.keymap.set('n', '<leader>f', function() vim.lsp.buf.format({ async = true }) end, opts('Format'))
        end,
      })
    end,
  },

  --------------------------------------------------------------------------------
  -- Autocomplete (nvim-cmp) + snippets (LuaSnip)
  --------------------------------------------------------------------------------
  {
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      { 'L3MON4D3/LuaSnip', build = 'make install_jsregexp' },
      'saadparwaiz1/cmp_luasnip',
    },
    config = function()
      local cmp = require('cmp')
      local luasnip = require('luasnip')
      cmp.setup({
        snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
        mapping = cmp.mapping.preset.insert({
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<CR>']      = cmp.mapping.confirm({ select = true }),
          ['<Tab>']     = cmp.mapping.select_next_item(),
          ['<S-Tab>']   = cmp.mapping.select_prev_item(),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'buffer' },
          { name = 'path' },
        }),
      })
    end,
  },
}
