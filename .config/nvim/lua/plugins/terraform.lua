return {
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "terraform", "hcl" } } },
  -- mason = false で Mason に取りに行かせず、PATH の terraform-ls を使う
  { "neovim/nvim-lspconfig", opts = { servers = { terraformls = { mason = false } } } },
}
