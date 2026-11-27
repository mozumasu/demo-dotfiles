# Ardia を使う

Ardia 用の MCP は、承認待ちで止まることが多かったので `.mcp.json` から外してある。安定したら、次のエントリを `.mcp.json` に戻し、Claude Code を再起動する。ツールは `mcp__plugin_browser-playwright_playwright__browser_*` になる。

```json
"playwright": {
  "command": "playwright-mcp",
  "args": [
    "--extension",
    "--executable-path",
    "${CLAUDE_PLUGIN_ROOT}/bin/ardia-open",
    "--output-dir",
    "${HOME}/.cache/playwright-mcp"
  ],
  "env": {
    "PLAYWRIGHT_MCP_USER_DATA_DIR": "${HOME}/Library/Application Support/com.ardia.browser/Chromium"
  }
}
```

## 設定の理由

- Ardia は `--remote-debugging-port` を無視するので、CDP のポートでつなぐ方法は使えない。拡張機能モードを使う
- `--executable-path` に `bin/ardia-open` を渡す。playwright は承認ページの URL をブラウザの実行ファイルに引数で渡すが、Ardia は起動済みのウィンドウへ渡すときにその URL を捨てる。`ardia-open` は最後の引数だけを `open -a Ardia` で渡す
- `PLAYWRIGHT_MCP_USER_DATA_DIR` にデータディレクトリを入れる。nixpkgs の `playwright-mcp` のラッパーは、この変数が空だと `PLAYWRIGHT_MCP_ISOLATED=1` を設定する。playwright は isolated かどうかを `--extension` より先に判定するので、空のままだと拡張機能モードにならず、一時プロファイルで新しいブラウザを起動しようとして失敗する。Chrome 用の設定も同じ理由で入れている

## 止まったとき

承認ページを開いた記録は `~/.local/state/browser-playwright/ardia-open.log` に残る。見方と対処は Chrome と同じで、ログに新しい行が増えなければ、`/mcp` で `playwright` を Reconnect してもらう。
