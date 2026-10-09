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
  },
}
