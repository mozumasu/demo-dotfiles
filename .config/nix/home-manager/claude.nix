{
  config,
  pkgs,
  lib,
  claude-code-japanese-guard,
  nix-secrets,
  ...
}:
let
  skillsDir = ../../claude/skills;
  # 管理しているキーを、オブジェクトは中まで辿って葉のパスの配列で返す
  # 配列は丸ごと置き換わるので葉として扱う
  mergeSettings = pkgs.writeText "merge-claude-settings.jq" ''
    def leaves:
      to_entries[]
      | if (.value | type) == "object" and (.value | length) > 0
        then [.key] + (.value | leaves)
        else [.key]
        end;
    .[0] as $current
    | .[1] as $previous
    | (.[2] * .[3]) as $managed
    | [$managed | leaves] as $paths
    | ($previous - $paths) as $stale
    | {
        settings: (($current | delpaths($stale)) * $managed),
        managed: $paths
      }
  '';
  # Claude Code がスラッシュコマンド (/config, /model, /theme 等) で ~/.claude/settings.json に書いた変更を dotfiles に取り込む
  # 非公開設定 (nix-secrets) 由来のキーは公開リポジトリに入れないよう除く。書き込んだ後は git diff で確認してからコミットする
  claudeSettingsPull = pkgs.writeShellApplication {
    name = "claude-settings-pull";
    runtimeInputs = [
      pkgs.jq
      pkgs.git
    ];
    text = ''
      SETTINGS="$HOME/.claude/settings.json"
      MANAGED="$HOME/.claude/.dotfiles-managed-keys.json"
      DOTFILES="${config.home.homeDirectory}/dotfiles"
      PUBLIC="$DOTFILES/.config/claude/settings.json"
      # 管理キーの記録がないと非公開設定のキーを見分けられず、公開リポジトリに漏れるので止める
      if [ ! -f "$MANAGED" ]; then
        echo "$MANAGED がない。darwin-rebuild switch を一度実行してから使う" >&2
        exit 1
      fi
      tmp="$(mktemp)"
      trap 'rm -f "$tmp"' EXIT
      # 非公開設定のキー = 前回マージした管理キーのうち公開設定にないもの。それを消した残りを公開設定とする
      # 消した結果空になったオブジェクト (autoMode など) は残さない
      jq -n \
        --slurpfile current "$SETTINGS" \
        --slurpfile managed "$MANAGED" \
        --slurpfile public "$PUBLIC" \
        -f ${pullSettings} > "$tmp"
      mv "$tmp" "$PUBLIC"
      trap - EXIT
      git -C "$DOTFILES" --no-pager diff -- "$PUBLIC"
    '';
  };
  pullSettings = pkgs.writeText "pull-claude-settings.jq" ''
    def leaves:
      to_entries[]
      | if (.value | type) == "object" and (.value | length) > 0
        then [.key] + (.value | leaves)
        else [.key]
        end;
    def prune:
      if type == "object"
      then with_entries(.value |= prune) | with_entries(select(.value != {}))
      else .
      end;
    ([$public[0] | leaves]) as $publicPaths
    | ($managed[0] - $publicPaths) as $secretPaths
    | ($current[0] | delpaths($secretPaths) | prune) as $result
    # 差分が並び替えだらけにならないよう、既存キーは dotfiles 側の順に並べ、新しいキーは後ろに足す
    | (reduce ($public[0] | keys_unsorted[] | select(. as $k | $result | has($k))) as $k ({}; .[$k] = $result[$k])) + $result
  '';
in
{
  # ~/.claude/settings.json はリンクせず、実ファイルに公開設定と非公開設定 (nix-secrets を sops で復号) をマージする
  # 仕事の情報を公開リポジトリに入れないため。Claude Code が /config などで書き込んだキーは実ファイルに残り、dotfiles 側のキーが優先される
  # 配列は連結ではなく後勝ちで置き換わる
  # 前回マージしたキーを .dotfiles-managed-keys.json に記録し、dotfiles と nix-secrets の両方から消えたキーは実ファイルからも消す
  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    SETTINGS="$HOME/.claude/settings.json"
    MANAGED="$HOME/.claude/.dotfiles-managed-keys.json"
    run mkdir -p "$HOME/.claude"
    WORK="$(mktemp -d "$HOME/.claude/.settings-merge.XXXXXX")"
    # 旧構成のリンクが残っていても、リンク先の内容を引き継いでから実ファイルに置き換える
    if [ -f "$SETTINGS" ]; then cat "$SETTINGS" > "$WORK/current.json"; else echo '{}' > "$WORK/current.json"; fi
    if [ -f "$MANAGED" ]; then cp "$MANAGED" "$WORK/previous.json"; else echo '[]' > "$WORK/previous.json"; fi
    if SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt" ${lib.getExe pkgs.sops} -d ${nix-secrets}/claude-settings.json > "$WORK/secret.json"; then
      SECRET_OK=1
    else
      warnEcho "Claude Code: 非公開設定を復号できないので公開設定だけマージする" >&2
      echo '{}' > "$WORK/secret.json"
      SECRET_OK=
    fi
    # 復号に失敗したときに非公開設定のキーを消さないよう、古いキーの削除はしない
    if [ -z "$SECRET_OK" ]; then echo '[]' > "$WORK/previous.json"; fi
    if ! ${lib.getExe pkgs.jq} -s -f ${mergeSettings} \
      "$WORK/current.json" \
      "$WORK/previous.json" \
      ${../../claude/settings.json} \
      "$WORK/secret.json" \
      > "$WORK/result.json"; then
      rm -rf "$WORK"
      errorEcho "Claude Code: settings.json のマージに失敗した"
      exit 1
    fi
    ${lib.getExe pkgs.jq} '.settings' "$WORK/result.json" > "$WORK/settings.json"
    chmod 644 "$WORK/settings.json"
    run mv "$WORK/settings.json" "$SETTINGS"
    if [ -n "$SECRET_OK" ]; then
      ${lib.getExe pkgs.jq} '.managed' "$WORK/result.json" > "$WORK/managed.json"
      run mv "$WORK/managed.json" "$MANAGED"
    fi
    rm -rf "$WORK"
  '';

  # skills/synced と共存させるため skills ディレクトリ全体ではなくスキル単位でリンクする
  # .config/claude/skills にディレクトリを置けば自動でリンクされる
  home.packages = [ claudeSettingsPull ];

  home.file =
    lib.mapAttrs' (
      name: _:
      lib.nameValuePair ".claude/skills/${name}" {
        source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/claude/skills/${name}";
      }
    ) (lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillsDir))
    // {
      ".claude/rules".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/claude/rules";
      # 応答が英語主体なら差し戻す Stop hook。/usr/bin/python3 は Xcode CLT のスタブなので nix の python3 で起動する
      ".claude/hooks/japanese-guard".source = pkgs.writeShellScript "japanese-guard" ''
        exec ${lib.getExe pkgs.python3} ${claude-code-japanese-guard}/hooks/japanese-guard.py "$@"
      '';
    };
}
