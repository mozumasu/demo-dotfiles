{ pkgs, ... }:
{
  # AWS のプロファイル・ロールを `assume` で切り替える
  # assume は AWS_* 環境変数を今のシェルに export するので、.zshrc で `source assume` する alias を張る
  # ~/.granted/config は初回実行時に granted 自身が書き込むので nix では管理しない
  home.packages = [ pkgs.granted ];
}
