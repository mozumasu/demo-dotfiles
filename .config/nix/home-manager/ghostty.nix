{ pkgs, lib, ... }:
let
  # herdr 用のキーを kitty キーボードプロトコルの CSI u 形式で直接送る (WezTerm と同じ)
  # mods の値は 1 + Shift(1) + Alt(2) + Ctrl(4) + Cmd(8)
  csiU =
    trigger: codepoint: mods:
    "${trigger}=text:\\x1b[${toString codepoint};${toString mods}u";
  digits = map toString (lib.range 1 9);
in
{
  programs.ghostty = {
    enable = true;
    # nixpkgs の ghostty は Linux 用。macOS では公式ビルドの .app を使う ghostty-bin を入れる
    package = pkgs.ghostty-bin;
    settings = {
      # OS のライト/ダークモードに追従して切り替わる。テーマ名の一覧は `ghostty +list-themes`
      theme = "light:iTerm2 Solarized Light,dark:Solarized Dark Patched";

      font-family = "HackGen Console NF";
      font-size = 13;

      # 背景の透過とぼかし
      background-opacity = 0.7;
      background-blur = 13;
      # 非フォーカスの分割ペインを薄暗くする (アクティブなペインが分かりやすい)
      unfocused-split-opacity = 0.7;

      cursor-style = "bar";

      # 端の余白 (ピクセル)。balance = true で左右上下を均等にする
      window-padding-x = 2;
      window-padding-y = 2;
      window-padding-balance = true;

      # タブをタイトルバーに統合する
      macos-titlebar-style = "tabs";

      # キーバインドは .config/wezterm/wezterm.lua に合わせる
      # Leader (C-;) はキーシーケンス (ctrl+semicolon>x) で再現する
      keybind = [
        # ペイン分割 (leader r: 右に分割, leader d: 下に分割)
        "ctrl+semicolon>r=new_split:right"
        "ctrl+semicolon>d=new_split:down"
        # ペインを閉じる (leader x)
        "ctrl+semicolon>x=close_surface"
        # タブの作成 (leader t)
        "ctrl+semicolon>t=new_tab"
        # タブの切り替え (leader Tab: 次, leader Shift+Tab: 前)
        "ctrl+semicolon>tab=next_tab"
        "ctrl+semicolon>shift+tab=previous_tab"
        # IME 経由だと C-q の 1 回目が消えるので、herdr の prefix 用に ^Q を直接送る
        "ctrl+q=text:\\x11"
        # Cmd+t (new_tab) / Ctrl+Tab / Ctrl+Shift+Tab (next_tab / previous_tab) は Ghostty の既定の割り当てを外し、
        # herdr が有効にする kitty キーボードプロトコルで届ける。CSI u を固定で送ると herdr の外で文字化けするため
        "super+t=unbind"
        "ctrl+tab=unbind"
        "ctrl+shift+tab=unbind"
        # Cmd+Ctrl+p / Cmd+Ctrl+n: previous_agent / next_agent
        # (Karabiner で Cmd+↑ / Cmd+↓ に変換されて届くので、矢印キーの修飾付き形式で送る)
        "super+arrow_up=text:\\x1b[1;9A"
        "super+arrow_down=text:\\x1b[1;9B"
        # Shift+Backspace: focus_pane_left
        (csiU "shift+backspace" 127 2)
      ]
      # Cmd+1..9 (switch_tab) も同じく kitty キーボードプロトコルに任せる
      ++ map (d: "super+${d}=unbind") digits
      # Ctrl+Shift+j/k/l: focus_pane_down/up/right, Ctrl+Shift+z: zoom
      ++ map (c: csiU "ctrl+shift+${c}" (lib.strings.charToInt c) 6) [
        "j"
        "k"
        "l"
        "z"
      ];
    };
  };
}
