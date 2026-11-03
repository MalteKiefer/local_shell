-- ~/.config/nvim/init.lua
-- Neovim 0.12 · Terraform · AWS · Go · Python · Shell/Fish · Linux
-- Tools (LSP/Formatter) kommen aus pixi global, nicht aus Mason.

------------------------------------------------------------------------
-- Grundeinstellungen
------------------------------------------------------------------------
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local o = vim.opt
o.number = true
o.relativenumber = true
o.cursorline = true
o.signcolumn = "yes"
o.scrolloff = 8
o.termguicolors = true
o.winborder = "rounded"
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.smartindent = true
o.ignorecase = true
o.smartcase = true
o.inccommand = "split"        -- Live-Vorschau bei :%s
o.splitright = true
o.splitbelow = true
o.undofile = true             -- Undo über Neustarts hinweg
o.updatetime = 250
o.timeoutlen = 400
o.confirm = true
o.list = true
o.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
o.clipboard = "unnamedplus"

-- Über SSH oder ohne grafische Sitzung (Container, ttyd): Zwischenablage per OSC52 ans Terminal
if os.getenv("SSH_TTY") or not (os.getenv("WAYLAND_DISPLAY") or os.getenv("DISPLAY")) then
  vim.g.clipboard = "osc52"
end

-- Einrückung je Sprache
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "terraform", "terraform-vars", "hcl", "yaml", "json", "jsonc", "lua", "toml" },
  callback = function() vim.opt_local.shiftwidth = 2; vim.opt_local.tabstop = 2 end,
})
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "go", "make" },
  callback = function() vim.opt_local.expandtab = false end,
})

-- AWS-Konfigdateien als INI erkennen
vim.filetype.add({
  pattern = {
    [".*/%.aws/config"] = "dosini",
    [".*/%.aws/credentials"] = "dosini",
  },
  filename = { [".terraformrc"] = "hcl", ["terraform.rc"] = "hcl" },
})

-- Kurz hervorheben, was gerade kopiert wurde
vim.api.nvim_create_autocmd("TextYankPost", { callback = function() vim.hl.on_yank() end })

------------------------------------------------------------------------
-- Allgemeine Tastenbelegung
------------------------------------------------------------------------
local map = vim.keymap.set
map("n", "<Esc>", "<cmd>nohlsearch<cr>")
map("n", "<C-h>", "<C-w>h"); map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k"); map("n", "<C-l>", "<C-w>l")
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Terminal verlassen" })
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Diagnose anzeigen" })

vim.diagnostic.config({
  severity_sort = true,
  virtual_text = { spacing = 2, source = "if_many" },
  float = { source = true },
})

-- Terminal im Ordner der aktuellen Datei (für terraform, aws, …)
local function term(cmd, opts)
  opts = opts or {}
  local dir = vim.fn.expand("%:p:h")
  if dir == "" then dir = vim.fn.getcwd() end
  vim.cmd(opts.tab and "tabnew" or "botright 15new")
  local buf = vim.api.nvim_get_current_buf()
  vim.fn.jobstart(cmd, {
    term = true,
    cwd = dir,
    on_exit = opts.close and vim.schedule_wrap(function()
      if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    end) or nil,
  })
  vim.cmd.startinsert()
end

map("n", "<leader>ti", function() term({ "terraform", "init" }) end, { desc = "terraform init" })
map("n", "<leader>tv", function() term({ "terraform", "validate" }) end, { desc = "terraform validate" })
map("n", "<leader>tp", function() term({ "terraform", "plan" }) end, { desc = "terraform plan" })
map("n", "<leader>tl", function() term({ "tflint" }) end, { desc = "tflint" })
map("n", "<leader>aw", function() term({ "aws", "sts", "get-caller-identity" }) end, { desc = "AWS: wer bin ich?" })
map("n", "<leader>gg", function() term({ "lazygit" }, { tab = true, close = true }) end, { desc = "lazygit" })

------------------------------------------------------------------------
-- Plugin-Manager lazy.nvim
------------------------------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- CloudFormation-Tags, damit yamlls bei !Ref & Co. nicht meckert
local cfn_tags = {
  "!Ref", "!Sub", "!Sub sequence", "!GetAtt", "!GetAtt sequence", "!Join sequence",
  "!If sequence", "!Equals sequence", "!Not sequence", "!And sequence", "!Or sequence",
  "!Select sequence", "!Split sequence", "!FindInMap sequence", "!ImportValue",
  "!Base64", "!GetAZs", "!Condition", "!Cidr sequence",
}

-- LSP-Server → Programm. Aktiviert wird nur, was installiert ist.
local servers = {
  terraformls  = "terraform-ls",
  tflint       = "tflint",
  gopls        = "gopls",
  ruff         = "ruff",
  basedpyright = "basedpyright-langserver",
  lua_ls       = "lua-language-server",
  bashls       = "bash-language-server",
  yamlls       = "yaml-language-server",
  jsonls       = "vscode-json-language-server",
  taplo        = "taplo",
  fish_lsp     = "fish-lsp",
  dockerls     = "docker-langserver",
}

require("lazy").setup({
  -- Farbschema passend zu fish/bat/fzf
  { "catppuccin/nvim", name = "catppuccin", priority = 1000,
    opts = { flavour = "mocha", auto_integrations = true },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin")
    end },

  -- Syntax via Treesitter (braucht tree-sitter-cli + C-Compiler)
  { "nvim-treesitter/nvim-treesitter", branch = "main", lazy = false, build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").install({
        "bash", "fish", "go", "gomod", "gosum", "hcl", "terraform", "python",
        "lua", "luadoc", "json", "yaml", "toml", "dockerfile", "make", "sql",
        "markdown", "markdown_inline", "gitcommit", "git_rebase", "diff",
        "regex", "vim", "vimdoc", "query",
      })
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          if pcall(vim.treesitter.start, args.buf) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end },

  -- Vervollständigung
  { "saghen/blink.cmp", version = "1.*",
    opts = {
      keymap = { preset = "enter" },
      completion = { documentation = { auto_show = true } },
      signature = { enabled = true },
      sources = { default = { "lsp", "path", "snippets", "buffer" } },
    } },

  -- Schemas für YAML/JSON (GitHub Actions, docker-compose, k8s, …)
  { "b0o/SchemaStore.nvim", lazy = true },
  -- Lua-LSP kennt die Neovim-API
  { "folke/lazydev.nvim", ft = "lua", opts = {} },

  -- LSP (Neovim-eigene API, Configs aus nvim-lspconfig)
  { "neovim/nvim-lspconfig", lazy = false,
    dependencies = { "saghen/blink.cmp", "b0o/SchemaStore.nvim" },
    config = function()
      vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })

      vim.lsp.config("yamlls", { settings = { yaml = {
        schemaStore = { enable = false, url = "" },
        schemas = require("schemastore").yaml.schemas(),
        customTags = cfn_tags,
        keyOrdering = false,
      } } })
      vim.lsp.config("jsonls", { settings = { json = {
        schemas = require("schemastore").json.schemas(),
        validate = { enable = true },
      } } })
      vim.lsp.config("gopls", { settings = { gopls = { staticcheck = true, gofumpt = false } } })
      vim.lsp.config("basedpyright", { settings = { basedpyright = {
        analysis = { typeCheckingMode = "standard" },
      } } })

      local enabled = {}
      for name, bin in pairs(servers) do
        if vim.fn.executable(bin) == 1 then table.insert(enabled, name) end
      end
      vim.lsp.enable(enabled)

      -- Eingebaut ab 0.11: K Hover, grn Umbenennen, gra Code-Action,
      -- grr Referenzen, gri Implementierung, gO Symbole, [d / ]d Diagnosen
      vim.api.nvim_create_autocmd("LspAttach", { callback = function(ev)
        local b = { buffer = ev.buf }
        map("n", "gd", vim.lsp.buf.definition, b)
        map("n", "gD", vim.lsp.buf.declaration, b)
        map("n", "<leader>ch", function()
          vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
        end, vim.tbl_extend("force", b, { desc = "Inlay-Hints an/aus" }))
      end })
    end },

  -- Formatieren beim Speichern
  { "stevearc/conform.nvim", event = "BufWritePre", cmd = "ConformInfo",
    keys = { { "<leader>cf", function() require("conform").format({ lsp_format = "fallback" }) end, desc = "Formatieren" } },
    opts = {
      formatters_by_ft = {
        terraform = { "terraform_fmt" },
        ["terraform-vars"] = { "terraform_fmt" },
        hcl = { "terraform_fmt" },
        go = { "gofmt" },
        python = { "ruff_organize_imports", "ruff_format" },
        sh = { "shfmt" }, bash = { "shfmt" },
        fish = { "fish_indent" },
        lua = { "stylua" },
        json = { "jq" },
        toml = { "taplo" },
      },
      format_on_save = function()
        if vim.g.noformat then return end
        return { timeout_ms = 1500, lsp_format = "fallback" }
      end,
    },
    init = function()
      vim.api.nvim_create_user_command("FormatToggle", function()
        vim.g.noformat = not vim.g.noformat
        print("Format on save: " .. (vim.g.noformat and "aus" or "an"))
      end, {})
    end },

  -- actionlint für GitHub-Workflows
  { "mfussenegger/nvim-lint", lazy = false, config = function()
      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
        pattern = { "*/.github/workflows/*.yml", "*/.github/workflows/*.yaml" },
        callback = function() require("lint").try_lint("actionlint") end,
      })
    end },

  -- Suche mit deinem fzf/fd/rg/bat/delta
  { "ibhagwan/fzf-lua", cmd = "FzfLua", opts = {},
    keys = {
      { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Dateien" },
      { "<leader>fg", "<cmd>FzfLua live_grep<cr>", desc = "Text suchen (rg)" },
      { "<leader>fw", "<cmd>FzfLua grep_cword<cr>", desc = "Wort unter Cursor" },
      { "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "Buffer" },
      { "<leader>fr", "<cmd>FzfLua resume<cr>", desc = "Letzte Suche" },
      { "<leader>fd", "<cmd>FzfLua diagnostics_workspace<cr>", desc = "Diagnosen" },
      { "<leader>fs", "<cmd>FzfLua lsp_document_symbols<cr>", desc = "Symbole" },
      { "<leader>fh", "<cmd>FzfLua helptags<cr>", desc = "Hilfe" },
      { "<leader>fk", "<cmd>FzfLua keymaps<cr>", desc = "Tastenbelegung" },
      { "<leader>gs", "<cmd>FzfLua git_status<cr>", desc = "Git Status" },
    } },

  -- Dateien bearbeiten wie einen Buffer
  { "stevearc/oil.nvim", lazy = false,
    opts = { view_options = { show_hidden = true } },
    keys = { { "-", "<cmd>Oil<cr>", desc = "Ordner öffnen" } } },

  -- Git im Editor
  { "lewis6991/gitsigns.nvim", event = "BufReadPre", opts = {},
    keys = {
      { "]h", function() require("gitsigns").nav_hunk("next") end, desc = "Nächste Änderung" },
      { "[h", function() require("gitsigns").nav_hunk("prev") end, desc = "Vorige Änderung" },
      { "<leader>gp", "<cmd>Gitsigns preview_hunk<cr>", desc = "Änderung anzeigen" },
      { "<leader>gb", "<cmd>Gitsigns blame_line<cr>", desc = "Blame" },
      { "<leader>gr", "<cmd>Gitsigns reset_hunk<cr>", desc = "Änderung verwerfen" },
    } },

  -- Statuszeile mit aktuellem AWS-Profil
  { "nvim-lualine/lualine.nvim",
    opts = {
      options = { theme = "catppuccin", globalstatus = true },
      sections = { lualine_x = {
        function()
          local p = os.getenv("AWS_PROFILE")
          return p and ("☁ " .. p) or ""
        end,
        "diagnostics", "filetype",
      } },
    } },

  -- Kleine Helfer
  { "echasnovski/mini.nvim", config = function()
      require("mini.pairs").setup()
      require("mini.surround").setup()    -- sa / sd / sr
      require("mini.ai").setup()
    end },

  -- Zeigt Tastenkürzel nach <leader>
  { "folke/which-key.nvim", event = "VeryLazy",
    opts = { preset = "helix", spec = {
      { "<leader>f", group = "Suchen" },
      { "<leader>g", group = "Git" },
      { "<leader>t", group = "Terraform" },
      { "<leader>c", group = "Code" },
      { "<leader>a", group = "AWS" },
    } } },
}, { checker = { enabled = false }, change_detection = { notify = false } })
