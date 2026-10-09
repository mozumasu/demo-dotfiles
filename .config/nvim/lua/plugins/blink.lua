return {
  "saghen/blink.cmp",
  opts = {
    keymap = {
      -- LazyVim の既定 "enter" プリセットをやめ、Enter で補完を確定しない
      preset = "default",
      ["<C-y>"] = { "select_and_accept", "fallback" },
      ["<Tab>"] = { "select_and_accept", "snippet_forward", "fallback" },
      ["<S-Tab>"] = { "snippet_backward", "fallback" },
    },
    cmdline = {
      keymap = {
        -- メニュー表示中は ↑↓ で候補を選択し、非表示時はコマンド履歴の移動にフォールバックする
        ["<Up>"] = { "select_prev", "fallback" },
        ["<Down>"] = { "select_next", "fallback" },
      },
    },
  },
}
