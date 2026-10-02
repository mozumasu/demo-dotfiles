{
  config,
  pkgs,
  lib,
  ccsession,
  zeno,
  ...
}:
{
  imports = [
    ./aerospace.nix
    ./git.nix
  ];
  home.username = "mozumasu";
  home.homeDirectory = "/Users/mozumasu";
  home.stateVersion = "24.11";
  programs.home-manager.enable = true;
  programs.ssh = {
    enable = true;
    # 旧デフォルト値の自動挿入を止める (将来 deprecated 予定。付けないと警告が出る)
    enableDefaultConfig = false;
    # 属性名が Host / Match で始まらなければ自動で "Host github.com" になる。"*" で Host * のデフォルトも書ける
    settings."github.com" = {
      IdentityFile = "~/.ssh/id_ed25519";
      # 初回にパスフレーズを入力したら ssh-agent とキーチェーンに保存し、以降は自動で使う
      AddKeysToAgent = "yes";
      # macOS 固有オプションもそのまま書ける
      UseKeychain = "yes";
    };
  };
  # ログイン時にキーチェーンのパスフレーズで鍵を ssh-agent に載せる
  # AddKeysToAgent は ssh 接続時しか効かず、コミット署名 (ssh-keygen -Y sign) だけだと毎回パスフレーズを聞かれるため
  # 事前に一度 `/usr/bin/ssh-add --apple-use-keychain ~/.ssh/id_ed25519` でキーチェーンに登録しておく
  launchd.agents.ssh-add-keychain = {
    enable = true;
    config = {
      ProgramArguments = [
        "/usr/bin/ssh-add"
        "--apple-load-keychain"
      ];
      RunAtLoad = true;
    };
  };
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/nvim";
  xdg.configFile."karabiner".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/karabiner";
  xdg.configFile."wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/wezterm";
  xdg.configFile."ccsession".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/ccsession";
  # 認証情報 (credentials.json / token.json) をリポジトリに入れないよう設定ファイルだけリンクする
  xdg.configFile."gmailctl/config.jsonnet".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/gmailctl/config.jsonnet";
  # ~/.config/herdr にはソケットやログ、セッション状態も置かれるので設定ファイルだけリンクする
  xdg.configFile."herdr/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/herdr/config.toml";
  xdg.configFile."zeno".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/zeno";
  # ~/.claude には認証情報や履歴、クラウド同期される skills/synced も置かれるので設定ファイルだけリンクする
  # Claude Code が書き換えた内容は dotfiles 側に差分として出るので git diff で確認する
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/claude/settings.json";
  # nb は ~/.nbrc 固定で読むのでホーム直下にリンクする
  home.file.".nbrc".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/nb/nbrc";
  # ZDOTDIR (~/.config/zsh) には .zcompdump などのキャッシュも置かれるのでファイル単位でリンクする
  xdg.configFile."zsh/.zshrc".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/zsh/.zshrc";
  # zsh の autoload 関数 (ファイル名 = 関数名)
  xdg.configFile."zsh/functions".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/zsh/functions";
  # 履歴から入力候補を薄く表示する。zeno と同じ ~/.local/share/zsh/plugins に置いて .zshrc から source する
  xdg.dataFile."zsh/plugins/zsh-autosuggestions".source =
    "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions";

  home.activation.macSKKDictionaries = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    DICT_DIR="$HOME/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries"
    mkdir -p "$DICT_DIR"
    cp -f "${pkgs.skkDictionaries.l}/share/skk/SKK-JISYO.L" "$DICT_DIR/"
    cp -f "${pkgs.skkDictionaries.jinmei}/share/skk/SKK-JISYO.jinmei" "$DICT_DIR/"
    cp -f "${pkgs.skkDictionaries.emoji}/share/skk/SKK-JISYO.emoji" "$DICT_DIR/"
    chmod 644 "$DICT_DIR"/SKK-JISYO.*
  '';

  # zeno.zsh は起動時に自分のディレクトリへ node_modules を作るので、読み取り専用の
  # nix store ではなく書き込める ~/.local/share/zsh/plugins/zeno にコピーして使う
  home.activation.zeno = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ZENO_DIR="${config.xdg.dataHome}/zsh/plugins/zeno"
    if [ "$(cat "$ZENO_DIR/.nix-source" 2>/dev/null)" != "${zeno}" ]; then
      rm -rf "$ZENO_DIR"
      mkdir -p "$(dirname "$ZENO_DIR")"
      cp -R "${zeno}" "$ZENO_DIR"
      chmod -R u+w "$ZENO_DIR"
      echo "${zeno}" > "$ZENO_DIR/.nix-source"
    fi
  '';

  home.packages = with pkgs; [
    # 最低限
    fzf
    zoxide
    neovim
    ripgrep
    # zeno.zsh の実行に必要
    deno
    # /usr/bin/python3 は Xcode CLT のスタブで、呼ぶとインストールダイアログが出るため nix 版を先に置く
    python3
    # treesitter パーサーのビルド用 (Xcode CLT なしで使える C コンパイラ)
    clang
    tree-sitter
    # バージョン管理
    git
    gh
    ghq
    lazygit
    # ファイラー
    yazi
    # Docker
    lazydocker
    # クラウド
    awscli2
    # Nix (フォーマッタと LSP。CLI と Neovim で同じバイナリを使うため Mason ではなく nix で入れる)
    nixfmt
    nixd
    llm-agents.claude-code
    llm-agents.codex
    llm-agents.pi
    nb
    # Gmail フィルタをコードで管理。設定ディレクトリが ~/.gmailctl 固定なので --config で XDG に寄せる
    (symlinkJoin {
      name = "gmailctl";
      paths = [ gmailctl ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/gmailctl --add-flags "--config ${config.xdg.configHome}/gmailctl"
      '';
    })
    ccsession.packages.${pkgs.system}.default
  ];
}
