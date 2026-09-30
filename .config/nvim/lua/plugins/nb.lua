return {
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
}
