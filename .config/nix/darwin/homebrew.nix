{ lib, browser, ... }:
{
  # サードパーティ tap の cask の brew trust は、nix-darwin が Brewfile の各項目に付ける trusted: true で済む
  homebrew = {
    enable = true;
    onActivation = {
      # Brewfile 外のパッケージを消さない
      cleanup = "none";
    };
    taps = [
      "ardia-browser/tap"
    ];
    brews = [
      "colima"
      "docker" # colima は実行環境だけなので CLI を別に入れる
      "sheldon"
    ];
    # robusta では browser.cask も ardia なので重複を除く
    casks = lib.unique [
      "homerow"
      browser.cask
      "wezterm"
      "raycast"
      "slack"
      "discord"
      "spotify"
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
      "aws-vpn-client"
      "google-chrome"
      "1password-cli" # op コマンド
      "ardia-browser/tap/ardia" # Arc 風のサイドバーを持つ Chromium ブラウザ (https://github.com/ardia-browser/ardia)
    ];
    # Mac App Store 限定のアプリ。mas で入れるので App Store にサインインしておく必要がある
    masApps = {
      "Endel" = 1346247457;
      "Kindle" = 302584613;
    };
  };
}
