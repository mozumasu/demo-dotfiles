---
name: browser
description: >
  Playwright MCP の拡張機能モードで、ログイン済みの Chrome を操作する（Ardia も設定を戻せば使える）。
  Notion、GitHub、AWS や New Relic のコンソールのように、ログインが要るページを
  ログインし直さずに読む・撮る・書き込むときに使う。「ブラウザで開いて」「Chrome で見て」
  「スクショを撮って」「PR に画像を貼って」「Notion のページを読んで（Notion MCP で見つからないとき）」などの依頼で使う。
---

# browser: Playwright の拡張機能でログイン済みのブラウザを操作する

このプラグインの `playwright-chrome` MCP は Chrome に入れた拡張機能「Playwright MCP Bridge」を通して、ログイン済みの Chrome のタブを操作する。ツールは `mcp__plugin_browser-playwright_playwright-chrome__browser_*`。

## つなぐとき

1. 最初の呼び出しで、Chrome に拡張機能の承認ページが開く。呼び出す前に、ユーザーに次の2つを伝える。
   - 承認ページが出たら許可して、触られてもよいタブを選んでほしい
   - 作業中はそのウィンドウを触らないでほしい（触ると接続が切れ、タブが about:blank になることがある）
2. 承認ページは `.mcp.json` の `CHROME_PROFILE_DIRECTORY`（今は `Default`）のプロファイルに開く。拡張機能は複数のプロファイルに入っているので、違うプロファイルで使いたいと言われたらこの値を変え、`/mcp` で Reconnect してもらう。
3. 2分たっても返らずバックグラウンドに回されたら、`~/.local/state/browser-playwright/chrome-open.log` に呼び出した時刻の行があるかを見る。
   - 行がある: 承認ページは開いている。どのプロファイルのウィンドウに出たかユーザーに確かめる
   - 行がない: 前の承認待ちで MCP が止まっている。待っているタスクを止め、ユーザーに `/mcp` で `playwright-chrome` を Reconnect してもらってから呼び直す

## 操作するとき

- ページは `browser_tabs` の `new` で新しいタブに開く。承認のときに選ばれたタブで `browser_navigate` すると、ユーザーのページを上書きしてしまう
- 本文を読むだけなら、`browser_snapshot` より `browser_evaluate` で `innerText` を取るほうが軽い
- `browser_take_screenshot` の保存先は `~/.cache/playwright-mcp` の下にする。scratchpad などほかの場所は書けない
- `browser_run_code_unsafe` の `page.waitForFunction` には `{ polling: 500 }` を付ける。既定の待ち方は画面の描画に合わせて判定するので、バックグラウンドのタブでは終わらない
- `browser_run_code_unsafe` の中では `import` が使えず、ローカルのファイルを読めない。ファイルの中身が要るときは、Bash で中身を埋め込んだスクリプトを `~/.cache/playwright-mcp` に書き、`filename` で渡す
- 接続が切れたら、`browser_tabs` の `list` で確かめ、`new` で開き直す

## サイトごとの注意

- **GitHub に画像を貼る**: コメント欄のファイル選択（`setInputFiles`）は止まる。画像を `File` にして、`#new_comment_field` に paste イベントとして送る。1回の paste で上がるのは1枚だけなので、1枚ずつ送り、欄に `user-attachments/assets/` の URL が入るのを待つ。投稿はブラウザでせず、URL を取り出して `gh pr comment` で行う
- **Notion**: 長いページは画面に入った部分しか描画されない。要素が見つからなければ、スクロールしながら探す。ワークスペースの検索や、内部の API の使い方は [references/notion.md](references/notion.md) を見る

## Ardia を使うとき

Ardia 用の MCP は、接続が安定しないので `.mcp.json` から外してある。戻し方は [references/ardia.md](references/ardia.md) を見る。

## 注意

- 接続している間、AI は選ばれたタブと自分で開いたタブを操作でき、Cookie も読める。触らせたくないページを開いたタブは選ばない
- `PLAYWRIGHT_MCP_EXTENSION_TOKEN` は設定しない。設定すると承認を省けるが、トークンを持つプロセスならどれでも、ログイン済みのブラウザにつなげるようになる
- 取得した内容を外（GitHub の Issue など）に書くときは、必要な部分だけにする
