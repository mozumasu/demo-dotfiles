{
  config,
  pkgs,
  lib,
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
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/nvim";

  home.activation.macSKKDictionaries = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    DICT_DIR="$HOME/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries"
    mkdir -p "$DICT_DIR"
    cp -f "${pkgs.skkDictionaries.l}/share/skk/SKK-JISYO.L" "$DICT_DIR/"
    cp -f "${pkgs.skkDictionaries.jinmei}/share/skk/SKK-JISYO.jinmei" "$DICT_DIR/"
    cp -f "${pkgs.skkDictionaries.emoji}/share/skk/SKK-JISYO.emoji" "$DICT_DIR/"
    chmod 644 "$DICT_DIR"/SKK-JISYO.*
  '';

  home.packages = with pkgs; [
    # 最低限
    fzf
    zoxide
    neovim
    ripgrep
    # バージョン管理
    git
    gh
    ghq
    lazygit
    # Docker
    lazydocker
    # Nix (フォーマッタと LSP。CLI と Neovim で同じバイナリを使うため Mason ではなく nix で入れる)
    nixfmt
    nixd
    llm-agents.claude-code
    llm-agents.codex
  ];
}
