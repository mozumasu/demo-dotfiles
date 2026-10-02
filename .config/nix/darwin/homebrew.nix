{ ... }:
{
  homebrew = {
    enable = true;
    onActivation = {
      # Brewfile 外のパッケージを消さない
      cleanup = "none";
      # サードパーティ tap の cask は brew trust が必要だが、activation は sudo 経由の隔離環境で動き
      # ユーザーの trust 情報を参照できない (aerospace が "untrusted tap" で失敗する) ため無効化
      extraEnv.HOMEBREW_NO_REQUIRE_TAP_TRUST = "1";
    };
    taps = [
      "mtgto/macskk"
      "nikitabobko/tap" # aerospace
    ];
    brews = [
      "colima"
      "sheldon"
      "herdr"
    ];
    casks = [
      "homerow"
      "aerospace" # タイル型ウィンドウマネージャ。設定は ~/.config/aerospace/aerospace.toml (Neovim と同じく mkOutOfStoreSymlink でリンク)
      "arc"
      "wezterm"
      "raycast"
      "slack"
      "discord"
      "shottr"
      "keycastr"
      "macskk"
      "karabiner-elements"
      # フォント (Nerd Font 入り。Neovim / ターミナルのアイコン表示に必要)
      "font-hackgen"
      "font-hackgen-nerd"
      "betterdisplay"
      # Cmd+Tab の置き換え。ウィンドウのないアプリ (Finder など) を一覧から外せる
      "alt-tab"
    ];
  };
}
