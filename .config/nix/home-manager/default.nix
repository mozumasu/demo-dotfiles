{ pkgs, ... }:
{
  home.username = "mozumasu";
  home.homeDirectory = "/Users/mozumasu";
  home.stateVersion = "24.11";
  programs.home-manager.enable = true;

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
  ];
}
