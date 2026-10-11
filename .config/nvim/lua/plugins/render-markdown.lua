-- setext 見出しを描画しないと下線の --- は生のまま残り、全幅の線になる区切り線と見た目が揃わない。
-- 下線も区切り線 (dash) と同じ線で上書きする
local setext_underline = vim.treesitter.query.parse("markdown", "(setext_h2_underline) @underline")

---@param ctx render.md.handler.Context
---@return render.md.Mark[]
local function parse_setext_underline(ctx)
  local marks = {} ---@type render.md.Mark[]
  for _, node in setext_underline:iter_captures(ctx.root, ctx.buf) do
    local row = node:range()
    marks[#marks + 1] = {
      conceal = "dash",
      start_row = row,
      start_col = 0,
      opts = {
        virt_text = { { string.rep("─", vim.o.columns), "RenderMarkdownDash" } },
        virt_text_pos = "overlay",
      },
    }
  end
  return marks
end

return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    -- snacks.gh (markdown.gh) と octo の issue/PR バッファでもレンダリングする
    -- file_types 未指定時は lazy の ft が使われ、ft は LazyVim の定義に追加される
    ft = { "markdown.gh", "octo" },
    opts = {
      heading = {
        -- Slidev のスライドごとの frontmatter (layout: 等の直後の ---) が setext 見出しと解釈され、
        -- 見出しとして塗られたうえ区切りの --- が隠れてしまうので setext 見出しは描画しない
        setext = false,
      },
      html = {
        -- 既定では <!-- --> のコメントが隠れて、コメントアウトした内容が見えなくなる
        comment = { conceal = false },
      },
      custom_handlers = {
        markdown = { extends = true, parse = parse_setext_underline },
      },
    },
  },
}
