-- LazyVim の ``` 補完 (コードブロックを閉じる) は filetype が markdown のときしか効かず、
-- octo バッファでは ``` が ```` になるので octo でも同じ挙動にする
local filetypes = { "octo" }

return {
  {
    "nvim-mini/mini.pairs",
    config = function(_, opts)
      LazyVim.mini.pairs(opts)
      local pairs = require("mini.pairs")
      local open = pairs.open
      pairs.open = function(pair, neigh_pattern)
        local o = pair:sub(1, 1)
        if o == "`" and vim.tbl_contains(filetypes, vim.bo.filetype) then
          local line = vim.api.nvim_get_current_line()
          local before = line:sub(1, vim.api.nvim_win_get_cursor(0)[2])
          if before:match("^%s*``") then
            return "`\n```" .. vim.api.nvim_replace_termcodes("<up>", true, true, true)
          end
        end
        return open(pair, neigh_pattern)
      end
    end,
  },
}
