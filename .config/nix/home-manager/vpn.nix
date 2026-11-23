{ config, nix-secrets, ... }:
{
  # vpn-i (L2TP) の構成プロファイル。nix-secrets に sops で暗号化して置いてあり、反映すると ~/.config/local/vpn.mobileconfig に復号する
  # macOS 11 以降は `profiles install` でユーザーのプロファイルを入れられないので、
  # `open ~/.config/local/vpn.mobileconfig` を実行し、システム設定 → 一般 → デバイス管理でインストールする
  # リンク先の実ファイルにも拡張子 .mobileconfig が付くよう、secret の名前に拡張子を付ける。付けないとシステム設定がプロファイルとして扱わない
  sops.secrets."vpn.mobileconfig" = {
    sopsFile = "${nix-secrets}/vpn.mobileconfig";
    format = "binary";
    path = "${config.home.homeDirectory}/.config/local/vpn.mobileconfig";
  };
}
