---
name: ardia-browser
description: >
  Playwright MCP の拡張機能モードで、ログイン済みの Ardia ブラウザを操作する。
  Notion、社内 SaaS、AWS や New Relic のコンソールのように、ログインが要るページを
  ログインし直さずに読みたいときに使う。「Ardia で開いて」「ブラウザで見て」
  「ログイン済みのページを読んで」「Notion のページを読んで（Notion MCP で見つからないとき）」などの依頼で使う。
---

# ardia-browser: Playwright の拡張機能で Ardia を操作する

このプラグインの playwright MCP（`.mcp.json` の `playwright` サーバー）は、Ardia に入れた拡張機能「Playwright Extension」を通して、普段使っている Ardia のタブを操作する。ログイン済みのセッションをそのまま使える。

Ardia は `--remote-debugging-port` を無視するので、Arc のように CDP のポートでつなぐ方法（arc-browser スキル）は使えない。

## 接続するとき

1. 最初の呼び出しで、Ardia に Playwright Extension の承認ページが開く。呼び出す前に、ユーザーに「Ardia に承認ページが出たら許可して、操作させるタブを選んでほしい」と伝える。
2. 承認されないと、呼び出しは 30 分応答がないまま止まり、タイムアウトする。2 分たって返らず、バックグラウンドに回されたら、承認ページが出ていないかユーザーに確かめる。
3. 接続は何かのきっかけで切れることがある。切れると、次の呼び出しで承認ページが開き直す。
4. 承認ページを開いた記録は `~/.local/state/ardia-playwright/ardia-open.log` に残る。承認ページが出ないと言われたら、このログに呼び出した時刻の行があるかを見る。

## 止まったとき

前の承認待ちのまま MCP が止まり、新しい呼び出しでも承認ページが開かないことがある（ログに新しい行が増えない）。そのときは、ユーザーに `/mcp` で playwright を Reconnect してもらってから呼び直す。

## タブの扱い

承認のときに選ばれたタブで `browser_navigate` すると、ユーザーが開いていたページを上書きしてしまう。ページを開くときは、`browser_tabs` の `new` で新しいタブを作ってから使う。

## ページを読む

- 本文を読むだけなら、`browser_snapshot` より `browser_evaluate` で `document.querySelector('main').innerText` を取るほうが軽い。
- Notion はページの中から内部の API を呼ぶと、ワークスペースの中を検索できる。claude.ai の Notion MCP が別のワークスペースにつながっていて見つからないときに使う。

  ```js
  async () => {
    // spaceId は、ワークスペース内のどれかのページの ID から引く
    const { spaceId } = await fetch('/api/v3/getPublicPageData', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ type: 'block-space', name: 'page', blockId: '<ページ ID>', requestedOnPublicDomain: false }),
    }).then(r => r.json());
    const res = await fetch('/api/v3/search', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        type: 'BlocksInSpace', query: '<検索語>', spaceId, limit: 20, sort: { field: 'relevance' }, source: 'quick_find',
        filters: { isDeletedOnly: false, excludeTemplates: false, navigableBlockContentOnly: false, requireEditPermissions: false,
          ancestors: [], createdBy: [], editedBy: [], lastEditedTime: {}, createdTime: {}, inTeams: [] },
      }),
    }).then(r => r.json());
    return res.results.map(r => ({ id: r.id, text: r.highlight?.text, path: r.highlight?.pathText }));
  }
  ```

- スナップショットやコンソールのログは `~/.cache/playwright-mcp` に出る（作業フォルダには出さない）。

## 設定の中身

設定はこのプラグインの `.mcp.json` にある。それぞれの理由は次のとおり。

- `--executable-path` に `bin/ardia-open` を渡す。playwright は承認ページの URL をブラウザの実行ファイルに引数で渡すが、Ardia は起動済みのウィンドウへ渡すときにその URL を捨てる。`ardia-open` は最後の引数だけを `open -a Ardia` で渡す。
- `PLAYWRIGHT_MCP_USER_DATA_DIR` に Ardia のデータディレクトリを入れる。nixpkgs の `playwright-mcp` のラッパーは、この変数が空だと `PLAYWRIGHT_MCP_ISOLATED=1` を設定する。playwright は isolated かどうかを `--extension` より先に判定するので、空のままだと拡張機能モードにならず、一時プロフィールで新しい Ardia を起動しようとして失敗する。
- `PLAYWRIGHT_MCP_EXTENSION_TOKEN` は設定しない。設定すると承認を省けるが、トークンを持つプロセスならどれでも、ログイン済みの Ardia につなげるようになる。

## 注意

- 接続している間、AI は選ばれたタブと自分で開いたタブを操作でき、Cookie も読める。触らせたくないページを開いたタブは選ばない。
- 取得した内容を外（GitHub の Issue など）に書くときは、必要な部分だけにする。
