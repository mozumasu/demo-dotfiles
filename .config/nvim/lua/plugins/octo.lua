-- octo の <details> 折りたたみの見た目を調整する
-- * 開いたときの範囲が分かるよう上下に罫線を引く
-- * ブロック全体に付く背景色 (OctoDetailsBlock = CursorLine) を外し、summary だけ色を付ける
-- * カーソル行では装飾を外して生のタグを見せ、編集できるようにする
local function customize_details()
  local folds = require("octo.folds")
  local octo_ns = vim.api.nvim_create_namespace("octo_details_folds")
  local ns = vim.api.nvim_create_namespace("octo_details_rules")

  local function set_hl()
    vim.api.nvim_set_hl(0, "OctoDetailsBlock", {})
    vim.api.nvim_set_hl(0, "OctoDetailsSummary", { default = true, link = "Title" })
    vim.api.nvim_set_hl(0, "OctoDetailsRule", { default = true, link = "Comment" })
    vim.api.nvim_set_hl(0, "OctoFolded", {})
  end
  set_hl()
  local group = vim.api.nvim_create_augroup("octo_details_hl", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_hl })
  -- 閉じた fold の summary の右側に Folded の背景が伸びるので外す
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    pattern = "octo://*",
    callback = function()
      vim.wo.winhighlight = "Folded:OctoFolded"
    end,
  })

  ---@type table<integer, {row:integer, marks:{ns:integer, id:integer, opts:table}[]}>
  local hidden = {}

  -- カーソル行で隠した装飾を元に戻す
  local function restore(bufnr)
    local h = hidden[bufnr]
    hidden[bufnr] = nil
    if not h then
      return
    end
    for _, m in ipairs(h.marks) do
      local pos = vim.api.nvim_buf_get_extmark_by_id(bufnr, m.ns, m.id, {})
      if pos[1] then
        m.opts.id = m.id
        vim.api.nvim_buf_set_extmark(bufnr, m.ns, pos[1], pos[2], m.opts)
      end
    end
    folds.update_details_arrows(bufnr)
  end

  -- カーソル行の overlay を外す
  local function reveal(bufnr)
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    if hidden[bufnr] and hidden[bufnr].row == row and vim.fn.foldclosed(row + 1) == -1 then
      return
    end
    restore(bufnr)
    -- 閉じた fold の summary 表示は octo の overlay に頼っているので外さない
    if vim.fn.foldclosed(row + 1) ~= -1 then
      return
    end
    local h = { row = row, marks = {} }
    for _, n in ipairs({ octo_ns, ns }) do
      for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, n, { row, 0 }, { row, -1 }, { details = true })) do
        local id, col, d = mark[1], mark[3], mark[4]
        if d.virt_text then
          local opts = {
            virt_text = d.virt_text,
            virt_text_pos = d.virt_text_pos,
            line_hl_group = d.line_hl_group,
            priority = d.priority,
          }
          table.insert(h.marks, { ns = n, id = id, opts = opts })
          vim.api.nvim_buf_set_extmark(bufnr, n, row, col, { id = id, line_hl_group = d.line_hl_group })
        end
      end
    end
    hidden[bufnr] = h
  end

  local create = folds.create_details_folds
  folds.create_details_folds = function(bufnr, start_line, end_line)
    hidden[bufnr] = nil -- 再描画で extmark は作り直される
    create(bufnr, start_line, end_line)
    vim.api.nvim_buf_clear_namespace(bufnr, ns, start_line - 1, end_line)
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
    local blocks = folds.parse_details_blocks(lines, start_line)

    for _, block in ipairs(blocks) do
      -- summary の overlay に色を付ける
      local row = block.open_line - 1
      for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, octo_ns, { row, 0 }, { row, -1 }, { details = true })) do
        local d = mark[4]
        if d.virt_text then
          d.virt_text[1][2] = "OctoDetailsSummary"
          vim.api.nvim_buf_set_extmark(bufnr, octo_ns, row, 0, {
            id = mark[1],
            virt_text = d.virt_text,
            virt_text_pos = "overlay",
            line_hl_group = d.line_hl_group,
          })
        end
      end

      -- 上の罫線は summary 行に引く (<details> 行は octo が summary を表示しているため)
      local rows = { block.close_line }
      for _, l in ipairs(block.tag_lines) do
        if l > block.open_line and l < block.close_line then
          table.insert(rows, l)
          break
        end
      end
      for _, r in ipairs(rows) do
        local indent = lines[r - start_line + 1]:match("^%s*")
        -- 罫線は画面端で切れるので長めに描く
        vim.api.nvim_buf_set_extmark(bufnr, ns, r - 1, #indent, {
          virt_text = { { ("─"):rep(300), "OctoDetailsRule" } },
          virt_text_pos = "overlay",
          priority = 5000,
        })
      end
    end

    if #blocks > 0 and not vim.b[bufnr].octo_details_reveal then
      vim.b[bufnr].octo_details_reveal = true
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufEnter" }, {
        buffer = bufnr,
        callback = function()
          reveal(bufnr)
        end,
      })
      vim.api.nvim_create_autocmd("BufLeave", {
        buffer = bufnr,
        callback = function()
          restore(bufnr)
        end,
      })
      -- zo/zc など CursorMoved が起きない fold 操作にも追従する
      local key_ns = vim.api.nvim_create_namespace("octo_details_reveal_" .. bufnr)
      local pending = false
      vim.on_key(function()
        if not vim.api.nvim_buf_is_valid(bufnr) then
          vim.on_key(nil, key_ns)
          return
        end
        if pending or vim.api.nvim_get_current_buf() ~= bufnr then
          return
        end
        pending = true
        vim.schedule(function()
          pending = false
          if vim.api.nvim_get_current_buf() == bufnr then
            reveal(bufnr)
          end
        end)
      end, key_ns)
    end
  end
end

return {
  {
    "pwntester/octo.nvim",
    config = function(_, opts)
      require("octo").setup(opts)
      customize_details()
    end,
  },
}
