---
name: takumi-guard-gha
description: GitHub Actions の workflow に Takumi Guard (flatt-security/setup-takumi-guard-npm) を導入・修正するときの手順と落とし穴。npm / pnpm / yarn / bun の install を Takumi Guard の proxy 経由にする step を足すとき、既存 workflow へ横展開するとき、導入後に publish や private registry の認証が 401 / 404 になったときに使う。「Takumi Guard を入れて」「setup-takumi-guard-npm」「悪性パッケージ対策を CI に入れたい」「npm.flatt.tech」などの依頼では、workflow を編集する前に必ずこの skill を読むこと。
---

# Takumi Guard を GitHub Actions に導入する

`flatt-security/setup-takumi-guard-npm` は、その job 内の npm / pnpm / yarn / bun の install を
Takumi Guard の proxy (`https://npm.flatt.tech/`) 経由にし、既知の悪性パッケージをブロックする action。
step を 1 つ足すだけに見えるが、job 全体の npm 設定を差し替えるため、前後の step と噛み合わないと
「この step だけ余計に走る」「後続の認証が効かない」といった問題がレビューや本番で発覚する。

## 手順

1. **対象を洗い出す**: `.github/workflows/` と composite action (`action.yml`) で、パッケージを install する job を探す
   (`npm ci` / `npm install` / `pnpm install` / `yarn` / `bun install`、install を内包する composite action も含む)。
2. **step を install の直前に置く**:

   ```yaml
   permissions:
     id-token: write   # bot-id を使う場合に必須 (OIDC で認証する)
     contents: read

   steps:
     - uses: actions/checkout@<sha> # vX.Y.Z
     - uses: ./.github/actions/setup   # toolchain の setup があればその後
     - name: Setup Takumi Guard (npm)
       uses: flatt-security/setup-takumi-guard-npm@<full-commit-sha> # vX.Y.Z
       with:
         bot-id: ${{ vars.<BOT_ID の変数名> }}
     - run: pnpm install
   ```

   - action は full commit SHA に pin し、バージョンをコメントに残す (`pinact run` で変換できる)。
   - `bot-id` は秘密情報ではないが、repository / organization variables に置き、既存 workflow と同じ変数名を使う。
   - `permissions` を job に書くと、書かなかった権限は none になる。既存の権限 (`contents: read` 等) を落とさない。
3. **install と同じ実行条件にする**: install の step や前後の step に `if:` が付いている場合は、Takumi Guard の
   step にも同じ `if:` を付ける。job 単位の `if:` は step に書き直す必要はない。
   - よくある形は「バージョンが変わったときだけ publish する」(`steps.version_check.outputs.version_changed == 'true'`)
     や「secret が未設定なら警告だけ出して全 step を skip する」(`steps.key.outputs.ok == 'true'`) といった、
     job 内の no-op 経路。後続 step がすべて同じ条件を持っていたら、Takumi Guard の step にも付ける。
   - 付け忘れると、何もしないはずの run でもこの step だけ認証を行う。bot-id 付きでは認証に失敗すると action が
     エラーで終わるため、Takumi Guard 側の障害などで no-op のはずの job が failure になり、`if: failure()` の
     通知 (Slack 等) まで飛ぶ。レビューでは blocker として指摘される。
   - 既存の workflow を修正するとき (401 の調査など、依頼の主題が別でも) この条件漏れを見つけたら一緒に直す。
4. **後続で `.npmrc` に書いている step を直す** (下記「`.npmrc` の書き込み先」)。
5. **同じ job で publish しているか確認する** (下記「publish」)。
6. **検証する**: `actionlint` を通し、PR の CI で install が `npm.flatt.tech` 経由になっていることをログで確認する。

## `.npmrc` の書き込み先

この action は `$RUNNER_TEMP/.npmrc` を作り、`NPM_CONFIG_USERCONFIG=$RUNNER_TEMP/.npmrc` を `$GITHUB_ENV` に書き出す。
npm / pnpm / Yarn Classic が読む user レベルの設定ファイルは 1 つだけなので、以降の step は `~/.npmrc` を読まなくなる。
(作成時に既存の `~/.npmrc` の中身はコピーされるが、それ以降に `~/.npmrc` へ追記した内容は反映されない。)

そのため、Takumi Guard の後で private registry の token などを `.npmrc` に書く step は、書き込み先を切り替える:

```sh
# NG: 読まれないファイルに書いている。publish や private package の install が 401 になる
printf '//npm.pkg.github.com/:_authToken=%s\n' "$NODE_AUTH_TOKEN" >> "$HOME/.npmrc"

# OK: NPM_CONFIG_USERCONFIG が設定されていればそのファイル、なければ ~/.npmrc に書く
printf '//npm.pkg.github.com/:_authToken=%s\n' "$NODE_AUTH_TOKEN" >> "${NPM_CONFIG_USERCONFIG:-$HOME/.npmrc}"
```

`npm config set` で書いている場合は、`NPM_CONFIG_USERCONFIG` の指すファイルに書かれるので変更不要。
書き込み先を変えたら、なぜ `${NPM_CONFIG_USERCONFIG:-...}` なのかが workflow だけで分かるよう、近くのコメントも
今の挙動 (Takumi Guard が書き込み先を切り替える) に合わせて更新する。古いコメントが残っているとレビューで指摘される。

逆に `actions/setup-node` の `registry-url` などで `NPM_CONFIG_USERCONFIG` が既に設定済みの場合、
Takumi Guard はそのファイルに追記するだけで、変数は変えない。

## publish

Takumi Guard の proxy は読み取り専用で、job のデフォルト registry になる。同じ job で publish すると proxy に向かって失敗する。

- `package.json` の `publishConfig.registry` か `--registry=...` で publish 先を明示する。
  すでに `publishConfig.registry` があれば対応不要。
- bun の `bun publish` は `publishConfig.registry` を無視する。`--registry` を渡し、その step で `BUN_CONFIG_TOKEN` を publish 用 token にする。

## fork からの pull request

GitHub は fork からの `pull_request` に OIDC token を出さないので、bot-id 付きの step は `OIDC not available` で失敗する。
fork からの PR を受ける repository (OSS 等) で `pull_request` の job に入れる場合は、fork のときだけ bot-id を空にする
(bot-id なしでもブロックは効き、監査ログに残らないだけ):

```yaml
with:
  # `cond && '' || x` は '' が falsy なので常に x になる。空文字を返したい側を || の右に置く
  bot-id: ${{ github.event.pull_request.head.repo.fork != true && vars.<BOT_ID の変数名> || '' }}
```

private repository で fork を使わない運用なら不要。

## よくあるエラー

| エラー | 原因と対処 |
|---|---|
| `OIDC not available` | job に `id-token: write` がない、または fork からの PR |
| `invalid ID token` / `Authentication failed` | Shisho Cloud 側の bot の trust condition が repository・trigger と合っていない |
| publish / private registry が 401 | 後続 step が `~/.npmrc` に token を書いている (上記「`.npmrc` の書き込み先」) |
| publish が proxy に向かって失敗 | publish 先を明示していない (上記「publish」) |

## その他の注意

- **長い job**: token の有効期限は既定で 30 分 (`expires-in`)。job の後半で install する場合は延ばす。
- **Dockerfile の build**: `$RUNNER_TEMP` は build context の外。`docker build --secret id=npmrc,src="$NPM_CONFIG_USERCONFIG"` で渡し、
  Dockerfile では `RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm ci` とする。`COPY .npmrc` は使えない。
- **commit 済みの project `.npmrc` に `//npm.flatt.tech/:_authToken=...` がある**: user レベルより優先されて bot の token が使われないので削除する。
- **Yarn Berry で `.yarnrc.yml` に `https://npm.flatt.tech` の `npmRegistries` がある**: そのエントリに `npmAlwaysAuth: true` を足す。

迷ったら、pin している SHA の action の `README.md` と `action.yml` を確認する
(`gh api "repos/flatt-security/setup-takumi-guard-npm/contents/action.yml?ref=<sha>" --jq .content | base64 -d`)。
