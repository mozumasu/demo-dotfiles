{ config, pkgs, ... }:
{
  imports = [
    ./aerospace.nix
    ./git.nix
  ];
  home.username = "mozumasu";
  home.homeDirectory = "/Users/mozumasu";
  home.stateVersion = "24.11";
  programs.home-manager.enable = true;
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/nvim";

  home.packages = with pkgs; [
    # 最低限
    fzf
    zoxide
    neovim
    ripgrep
    # バージョン管理
    git
    gh
    ghq
    lazygit
    # Docker
    lazydocker
    # Nix (フォーマッタと LSP。CLI と Neovim で同じバイナリを使うため Mason ではなく nix で入れる)
    nixfmt
    nixd
  ];
}
