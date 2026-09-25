{ ... }:
{
  programs.aerospace = {
    enable = true;
    # package は既定の pkgs.aerospace (null にしない。launchd と reload-config が実体を必要とする)
    # 起動を launchd で管理する (start-at-login / after-login-command は自動で無効化される)。
    # 初回は「バックグラウンド項目を許可」のダイアログが出る
    launchd.enable = true;
    settings = {
      # config-version 1 は persistent-workspaces をキーバインドの右辺から推測していて誤りやすかったため廃止予定。
      # 2 では明示する (書かないと空扱いになり、ウィンドウの無いワークスペースが消える)
      config-version = 2;
      persistent-workspaces = [
        "1"
        "2"
        "3"
        "4"
        "5"
        "6"
        "7"
        "8"
        "9"
        "A"
        "B"
        "D"
        "E"
        "F"
        "I"
        "M"
        "N"
        "P"
        "Q"
        "R"
        "S"
        "T"
        "U"
        "W"
        "X"
        "Y"
        "Z"
      ];
      # borders (brew "felixkratz/formulae/borders") でフォーカス中ウィンドウに枠を付ける。入れていなければ削る
      after-startup-command = [ "exec-and-forget borders" ];
      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;
      accordion-padding = 20;
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";
      # フォーカスしたモニタへマウスも移動
      on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];
      automatically-unhide-macos-hidden-apps = false;
      key-mapping.preset = "qwerty";
      gaps = {
        inner = {
          horizontal = 3;
          vertical = 3;
        };
        outer = {
          left = 3;
          bottom = 3;
          top = 3;
          right = 3;
        };
      };

      mode.main.binding = {
        # レイアウト
        alt-slash = "layout tiles horizontal vertical";
        alt-comma = "layout accordion horizontal vertical";
        alt-shift-space = "layout floating tiling"; # フォーカス中ウィンドウの floating / tiling をトグル
        # フォーカス移動 (vim キー)
        alt-h = "focus left";
        alt-j = "focus down";
        alt-k = "focus up";
        alt-l = "focus right";
        # ウィンドウ移動
        alt-shift-h = "move left";
        alt-shift-j = "move down";
        alt-shift-k = "move up";
        alt-shift-l = "move right";
        # リサイズ
        alt-minus = "resize smart -50";
        alt-shift-minus = "resize smart +50";
        # ワークスペース切り替え (数字 + 用途別の英字)
        alt-1 = "workspace 1";
        alt-2 = "workspace 2";
        alt-3 = "workspace 3";
        alt-4 = "workspace 4";
        alt-5 = "workspace 5";
        alt-6 = "workspace 6";
        alt-7 = "workspace 7";
        alt-8 = "workspace 8";
        alt-9 = "workspace 9";
        alt-a = "workspace A";
        alt-d = "workspace D";
        alt-e = "workspace E";
        alt-i = "workspace I";
        alt-m = "workspace M";
        alt-n = "workspace N";
        alt-r = "workspace R";
        alt-u = "workspace U";
        alt-w = "workspace W";
        alt-y = "workspace Y";
        alt-z = "workspace Z";
        # alt-x は Raycast の WezTerm ホットキーに使うので空けておく
        # ウィンドウをワークスペースへ移動
        alt-shift-1 = "move-node-to-workspace 1";
        alt-shift-2 = "move-node-to-workspace 2";
        alt-shift-3 = "move-node-to-workspace 3";
        alt-shift-4 = "move-node-to-workspace 4";
        alt-shift-5 = "move-node-to-workspace 5";
        alt-shift-6 = "move-node-to-workspace 6";
        alt-shift-7 = "move-node-to-workspace 7";
        alt-shift-8 = "move-node-to-workspace 8";
        alt-shift-9 = "move-node-to-workspace 9";
        alt-shift-a = "move-node-to-workspace A";
        alt-shift-b = "move-node-to-workspace B";
        alt-shift-d = "move-node-to-workspace D";
        alt-shift-e = "move-node-to-workspace E";
        alt-shift-f = "move-node-to-workspace F";
        alt-shift-i = "move-node-to-workspace I";
        alt-shift-m = "move-node-to-workspace M";
        alt-shift-n = "move-node-to-workspace N";
        alt-shift-p = "move-node-to-workspace P";
        alt-shift-q = "move-node-to-workspace Q";
        alt-shift-r = "move-node-to-workspace R";
        alt-shift-s = "move-node-to-workspace S";
        alt-shift-t = "move-node-to-workspace T";
        alt-shift-u = "move-node-to-workspace U";
        alt-shift-w = "move-node-to-workspace W";
        alt-shift-x = "move-node-to-workspace X";
        alt-shift-y = "move-node-to-workspace Y";
        alt-shift-z = "move-node-to-workspace Z";
        # 直前のワークスペースと行き来 / ワークスペースを隣のモニタへ
        alt-tab = "workspace-back-and-forth";
        alt-shift-tab = "move-workspace-to-monitor --wrap-around next";
        # モニタ間のフォーカス / 移動 (cmd-ctrl-h は macOS が cmd-backspace に変換するため backspace)
        cmd-backspace = "focus-monitor left";
        cmd-ctrl-l = "focus-monitor right";
        cmd-ctrl-k = "focus-monitor up";
        cmd-ctrl-j = "focus-monitor down";
        cmd-shift-backspace = "move-node-to-monitor left";
        cmd-ctrl-shift-l = "move-node-to-monitor right";
        cmd-ctrl-shift-k = "move-node-to-monitor up";
        cmd-ctrl-shift-j = "move-node-to-monitor down";
        # service モードへ
        alt-shift-semicolon = "mode service";
      };

      # service モード: alt-shift-; で入り、1 操作して main に戻る
      mode.service.binding = {
        esc = [
          "reload-config"
          "mode main"
        ];
        r = [
          "flatten-workspace-tree"
          "mode main"
        ]; # レイアウトをリセット
        f = [
          "layout floating tiling"
          "mode main"
        ];
        backspace = [
          "close-all-windows-but-current"
          "mode main"
        ];
      };

      # アプリごとの初期配置 (app-id は `aerospace list-apps` で調べる)。if は Nix の予約語なので引用符で囲む
      on-window-detected = [
        {
          "if".app-id = "company.thebrowser.Browser";
          run = "move-node-to-workspace 1";
        } # Arc
        {
          "if".app-id = "com.github.wez.wezterm";
          run = "move-node-to-workspace 2";
        }
        {
          "if".app-id = "com.tinyspeck.slackmacgap";
          run = "move-node-to-workspace 3";
        }
        {
          "if".app-id = "com.mitchellh.ghostty";
          run = "layout floating";
        }
        {
          "if".app-id = "com.spotify.client";
          run = "move-node-to-workspace M";
        }
        {
          "if".app-id = "notion.id";
          run = "move-node-to-workspace N";
        }
        {
          "if".app-id = "us.zoom.xos";
          run = "move-node-to-workspace Z";
        }
      ];
      # Zoom のワークスペースは外部ディスプレイに固定
      workspace-to-monitor-force-assignment.Z = [ "Display" ];
    };
  };
}
