return {
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "nix" } } },
  -- 保存時フォーマット。PATH の nixfmt (nix で入れたもの) が使われる
  { "stevearc/conform.nvim", opts = { formatters_by_ft = { nix = { "nixfmt" } } } },
  -- mason = false で Mason に取りに行かせず、PATH の nixd を使う
  { "neovim/nvim-lspconfig", opts = { servers = { nixd = { mason = false } } } },
}
