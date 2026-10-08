return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    -- snacks.gh (markdown.gh) と octo の issue/PR バッファでもレンダリングする
    -- file_types 未指定時は lazy の ft が使われ、ft は LazyVim の定義に追加される
    ft = { "markdown.gh", "octo" },
  },
}
