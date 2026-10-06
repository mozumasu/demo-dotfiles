return {
  {
    "mozumasu/nb.nvim",
    dependencies = { "folke/snacks.nvim" },
    lazy = false, -- load at startup so autosync autocmds are registered
    opts = {},
    -- stylua: ignore
    keys = {
      { "<leader>na", function() require("nb").add() end, desc = "nb add" },
      { "<leader>nA", function() require("nb").add_select() end, desc = "nb add (select notebook)" },
      { "<leader>ni", function() require("nb").import_image() end, desc = "nb import image" },
      { "<leader>nl", function() require("nb").link() end, desc = "nb link" },
      { "<leader>nm", function() require("nb").move() end, desc = "nb move to notebook" },
      { "<leader>nM", function() require("nb").adopt_buffer() end, desc = "nb adopt current buffer" },
      { "<leader>np", function() require("nb").pick() end, desc = "nb picker" },
      { "<leader>ng", function() require("nb").grep() end, desc = "nb grep" },
    },
  },
  -- nb のノートはファイル名がタイムスタンプなので、バッファ一覧とステータスラインにはノートのタイトルを出す
  {
    "akinsho/bufferline.nvim",
    optional = true,
    opts = {
      options = {
        name_formatter = function(buf)
          return require("nb").get_title(buf.path) or buf.name
        end,
      },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      -- LazyVim が lualine_c に入れる pretty_path をラップし、nb のノートなら "notebook/ タイトル" にする
      for _, component in ipairs(opts.sections.lualine_c) do
        if type(component) == "table" and vim.tbl_count(component) == 1 and type(component[1]) == "function" then
          local pretty_path = component[1]
          component[1] = function(self)
            local path = vim.fn.expand("%:p")
            local title = path ~= "" and require("nb").get_title(path)
            if not title then
              return pretty_path(self)
            end
            local format = LazyVim.lualine.format
            local notebook = require("nb").notebook_of(path)
            local name = format(self, title, vim.bo.modified and "MatchParen" or "Bold")
            return notebook and format(self, notebook .. "/", "") .. name or name
          end
          break
        end
      end
    end,
  },
}
