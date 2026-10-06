-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("n", "sh", "<C-w>h", { desc = "Move to left window" })
vim.keymap.set("n", "sj", "<C-w>j", { desc = "Move to lower window" })
vim.keymap.set("n", "sk", "<C-w>k", { desc = "Move to upper window" })
vim.keymap.set("n", "sl", "<C-w>l", { desc = "Move to right window" })

-- バッファ内でスペルミス扱いの単語をまとめて辞書に登録する（zg を 1 語ずつ打つ代わり）
-- ]s で移動して集めるので、treesitter でスペルチェック対象外のコードブロックや URL は含まれない
vim.api.nvim_create_user_command("SpellGoodAll", function()
  if not vim.wo.spell then
    vim.notify("spell が無効です", vim.log.levels.WARN)
    return
  end
  local view = vim.fn.winsaveview()
  local wrapscan = vim.o.wrapscan
  vim.o.wrapscan = true
  -- 末尾から ]s すると先頭に回り込むので、最初の位置に戻るまで集める
  vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(0), 0 })
  vim.cmd("normal! $")
  local words, seen, first = {}, {}, nil
  while true do
    local before = vim.api.nvim_win_get_cursor(0)
    pcall(vim.cmd, "silent normal! ]s")
    local pos = vim.api.nvim_win_get_cursor(0)
    if (pos[1] == before[1] and pos[2] == before[2]) or (first and pos[1] == first[1] and pos[2] == first[2]) then
      break
    end
    first = first or pos
    local word, kind = unpack(vim.fn.spellbadword())
    if word ~= "" and kind == "bad" and not seen[word] then
      seen[word] = true
      table.insert(words, word)
    end
  end
  vim.o.wrapscan = wrapscan
  vim.fn.winrestview(view)

  if #words == 0 then
    vim.notify("スペルミス扱いの単語はありません")
    return
  end
  local msg = ("%d 語を辞書に追加しますか?\n%s"):format(#words, table.concat(words, ", "))
  if vim.fn.confirm(msg, "&Yes\n&No", 2) ~= 1 then
    return
  end
  for _, word in ipairs(words) do
    vim.cmd.spellgood({ args = { word }, mods = { silent = true } })
  end
  vim.notify(("%d 語を辞書に追加しました"):format(#words))
end, { desc = "Add all misspelled words in the buffer to the spellfile" })
vim.keymap.set("n", "<leader>zg", "<cmd>SpellGoodAll<cr>", { desc = "Add all misspelled words to spellfile" })
