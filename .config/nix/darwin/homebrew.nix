{
  config,
  lib,
  browser,
  ...
}:
{
  # サードパーティ tap の cask は brew trust が要る。brew bundle と同じく sudo --set-home でユーザーとして
  # 実行し、~/.homebrew/trust.json に記録する。nix-homebrew の brew の用意 (mkBefore) と brew bundle の間で動かす
  system.activationScripts.homebrew.text = lib.mkOrder 750 ''
    if [ -f "${config.homebrew.prefix}/bin/brew" ]; then
      sudo --user=${lib.escapeShellArg config.homebrew.user} --set-home \
        "${config.homebrew.prefix}/bin/brew" trust --tap ${
          lib.escapeShellArgs (map (t: t.name) config.homebrew.taps)
        } >/dev/null
    fi
  '';

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
      "ardia-browser/tap/ardia" # Arc 風のサイドバーを持つ Chromium ブラウザ (https://github.com/ardia-browser/ardia)
    ];
    # Mac App Store 限定のアプリ。mas で入れるので App Store にサインインしておく必要がある
    masApps = {
      "Endel" = 1346247457;
      "Kindle" = 302584613;
    };
  };
}
