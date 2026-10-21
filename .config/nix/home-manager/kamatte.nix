{ config, ... }:
{
  # kamatte の接続先 (kamatte リポジトリの secrets/mozumasu.yaml) は age 公開鍵で暗号化されていて、sops-nix がこの秘密鍵で復号する
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  programs.kamatte = {
    enable = true;
    user = "mozumasu";
  };
}
