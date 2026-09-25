{ ... }:
{
  # tree root を決めるファイル。flake.nix にすると root が .config/nix になり、
  # .config/nvim/**/*.lua のような includes が一切当たらなくなる。リポジトリ直下にある .git/config を指定する
  projectRootFile = ".git/config";
  programs.nixfmt.enable = true;
  programs.stylua.enable = true;
  settings.formatter.stylua.includes = [ ".config/nvim/**/*.lua" ];
}
