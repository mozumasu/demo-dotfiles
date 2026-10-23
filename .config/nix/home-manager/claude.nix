{
  config,
  pkgs,
  lib,
  claude-code-japanese-guard,
  yomiyasu,
  nix-secrets,
  ...
}:
let
  skillsDir = ../../claude/skills;
  # dir/skills/<name> に dotfiles のスキルを 1 つずつリンクする
  skillLinks =
    dir:
    lib.mapAttrs' (
      name: _:
      lib.nameValuePair "${dir}/skills/${name}" {
        source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/claude/skills/${name}";
      }
    ) (lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillsDir));
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
      # 既定は ~/.claude から取り込む。個人用 (claude-p) から取り込むときだけ --personal を付ける
      # claude-p の中で実行しても CLAUDE_CONFIG_DIR は見ない。気づかずに個人用の設定を取り込まないため
      CONFIG_DIR="$HOME/.claude"
      if [ "''${1:-}" = "--personal" ]; then
        CONFIG_DIR="$HOME/.claude-personal"
      elif [ -n "''${1:-}" ]; then
        echo "usage: claude-settings-pull [--personal]" >&2
        exit 2
      fi
      SETTINGS="$CONFIG_DIR/settings.json"
      MANAGED="$CONFIG_DIR/.dotfiles-managed-keys.json"
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
  # dir の settings.json に公開設定をマージする。withSecret のときは非公開設定 (nix-secrets) も重ねる
  mergeSettingsInto =
    { dir, withSecret }:
    let
      secretStep =
        if withSecret then
          ''
            if SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt" ${lib.getExe pkgs.sops} -d ${nix-secrets}/claude-settings.json > "$WORK/secret.json"; then
              SECRET_OK=1
            else
              warnEcho "Claude Code: 非公開設定を復号できないので公開設定だけマージする" >&2
              echo '{}' > "$WORK/secret.json"
              SECRET_OK=
            fi
          ''
        else
          ''
            echo '{}' > "$WORK/secret.json"
            SECRET_OK=1
          '';
    in
    ''
      SETTINGS="${dir}/settings.json"
      MANAGED="${dir}/.dotfiles-managed-keys.json"
      # dry-run では mkdir が飛ばされ、初回はディレクトリがなくて mktemp が失敗するので、マージ自体を飛ばす
      if [[ -v DRY_RUN ]]; then
        verboseEcho "Claude Code: dry-run なので ${dir}/settings.json のマージを飛ばす"
        exit 0
      fi
      mkdir -p "${dir}"
      WORK="$(mktemp -d "${dir}/.settings-merge.XXXXXX")"
      # 旧構成のリンクが残っていても、リンク先の内容を引き継いでから実ファイルに置き換える
      if [ -f "$SETTINGS" ]; then cat "$SETTINGS" > "$WORK/current.json"; else echo '{}' > "$WORK/current.json"; fi
      if [ -f "$MANAGED" ]; then cp "$MANAGED" "$WORK/previous.json"; else echo '[]' > "$WORK/previous.json"; fi
      ${secretStep}
      # 復号に失敗したときに非公開設定のキーを消さないよう、古いキーの削除はしない
      if [ -z "$SECRET_OK" ]; then echo '[]' > "$WORK/previous.json"; fi
      if ! ${lib.getExe pkgs.jq} -s -f ${mergeSettings} \
        "$WORK/current.json" \
        "$WORK/previous.json" \
        ${../../claude/settings.json} \
        "$WORK/secret.json" \
        > "$WORK/result.json"; then
        rm -rf "$WORK"
        errorEcho "Claude Code: ${dir}/settings.json のマージに失敗した"
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
in
{
  # ~/.claude/settings.json はリンクせず、実ファイルに公開設定と非公開設定 (nix-secrets を sops で復号) をマージする
  # 仕事の情報を公開リポジトリに入れないため。Claude Code が /config などで書き込んだキーは実ファイルに残り、dotfiles 側のキーが優先される
  # 配列は連結ではなく後勝ちで置き換わる
  # 前回マージしたキーを .dotfiles-managed-keys.json に記録し、dotfiles と nix-secrets の両方から消えたキーは実ファイルからも消す
  # 2 つのマージはサブシェルで分け、変数を共有せず、片方が失敗してももう片方は実行する。失敗があれば最後に止める
  # サブシェルを || や if の中に置くと set -e が効かなくなるので、set +e で外側だけ緩めて終了コードを受け取る
  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    set +e
    (
      set -e
      ${mergeSettingsInto {
        dir = "$HOME/.claude";
        withSecret = true;
      }}
    )
    claudeWorkStatus=$?
    # 個人アカウント用 (claude-p) には会社の非公開設定を入れない
    (
      set -e
      ${mergeSettingsInto {
        dir = "$HOME/.claude-personal";
        withSecret = false;
      }}
    )
    claudePersonalStatus=$?
    set -e
    if [ "$claudeWorkStatus" -ne 0 ] || [ "$claudePersonalStatus" -ne 0 ]; then
      exit 1
    fi
  '';

  # skills/synced と共存させるため skills ディレクトリ全体ではなくスキル単位でリンクする
  # .config/claude/skills にディレクトリを置けば自動でリンクされる
  home.packages = [ claudeSettingsPull ];

  home.file =
    skillLinks ".claude"
    # 個人アカウント用 (claude-p) にも dotfiles のスキルをスキル単位でリンクする
    # ~/.claude/skills を丸ごとリンクすると、会社の組織から同期されるスキル (skills/synced) まで共有してしまうため
    // skillLinks ".claude-personal"
    // {
      ".claude/rules".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/claude/rules";
      # 個人アカウント用 (CLAUDE_CONFIG_DIR=~/.claude-personal で起動する claude-p) も ~/.claude と同じルール・スキルを使う
      # hook は settings.json から ~/.claude/hooks の絶対パスで呼ぶのでリンクしない
      # settings.json は会社の非公開設定を入れないよう別にマージする。認証・履歴・プラグインのインストール状態もディレクトリごとに分かれる
      ".claude-personal/rules".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/claude/rules";
      # 応答が英語主体なら差し戻す Stop hook。/usr/bin/python3 は Xcode CLT のスタブなので nix の python3 で起動する
      # 外部リポジトリのスキル。更新は nix flake update yomiyasu
      ".claude/skills/yomiyasu".source = "${yomiyasu}/skills/yomiyasu";
      ".claude-personal/skills/yomiyasu".source = "${yomiyasu}/skills/yomiyasu";
      ".claude/hooks/japanese-guard".source = pkgs.writeShellScript "japanese-guard" ''
        exec ${lib.getExe pkgs.python3} ${claude-code-japanese-guard}/hooks/japanese-guard.py "$@"
      '';
    };
}
