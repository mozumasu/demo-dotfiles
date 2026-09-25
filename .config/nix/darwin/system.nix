{ ... }:
{
  system.stateVersion = 5;

  # sudo を Touch ID で通す (/etc/pam.d/sudo_local に pam_tid.so を書く)
  security.pam.services.sudo_local.touchIdAuth = true;
  # tmux / screen / zellij などサーバー型マルチプレクサの中でも Touch ID を効かせる (pam_reattach)
  security.pam.services.sudo_local.reattach = true;

  # caps lock → control
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };

  system.defaults = {
    NSGlobalDomain = {
      # キーリピート中の連打間隔 (15ms 単位。小さいほど速い、最速は 1)
      KeyRepeat = 1;
      # 押しっぱなしにしてからリピートが始まるまでの時間 (15ms 単位。10 未満は誤爆しやすい)
      InitialKeyRepeat = 12;
      # アラート音 (ターミナルのベル含む) を無音に
      "com.apple.sound.beep.volume" = 0.0;
    };
    # Dock アイコンの大きさ (px)。UI スライダーの範囲は 16〜128、16 が最小
    dock.tilesize = 16;
    # カーソルを乗せたアイコンを拡大する
    dock.magnification = true;
    # 拡大時の大きさ (px)。範囲は 16〜128 で UI の「小」が 16。tilesize と同じ値だと拡大しても変化しない
    dock.largesize = 32;
    # Dock を隠して、画面下にカーソルを持っていったときだけ表示する
    dock.autohide = true;
    # カーソルを当ててから表示されるまでの待ち時間 (秒)。0 で即表示
    dock.autohide-delay = 0.0;
    # 表示アニメーションの長さ (秒)。0 でアニメーションなし
    dock.autohide-time-modifier = 0.0;
    # タップでクリック
    trackpad.Clicking = true;
    # ダブルタップして指を離さずにドラッグ (タップでドラッグ)
    trackpad.Dragging = true;
    # 指を離してもドラッグを続けるロック機能。true にすると再タップするまで掴んだまま
    trackpad.DragLock = false;
    # カーソルのスピード (UI スライダーの最大は 3.0、それ以上も指定可)
    CustomUserPreferences.NSGlobalDomain."com.apple.trackpad.scaling" = 5.0;
    ".GlobalPreferences"."com.apple.mouse.scaling" = 5.0;
  };

  # 起動音オフ (nvram の StartupMute を書く)
  system.startup.chime = false;
}
