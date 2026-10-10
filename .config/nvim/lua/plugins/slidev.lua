-- markdownlint-cli2 --fix は Slidev のスライドごとの frontmatter (--- で挟んだ layout: 等) を本文として扱い、
-- URL を <> で囲む・リストの前に空行を入れる・インデントを外すなどして壊してしまう。
-- 診断も同じ理由で誤検知だらけになるので、package.json の依存に @slidev/cli があるプロジェクトでは
-- markdownlint-cli2 で整形も lint もしない

---@param dir string
local function is_slidev(dir)
  for _, pkg in ipairs(vim.fs.find("package.json", { upward = true, path = dir, limit = math.huge })) do
    local ok, json = pcall(vim.json.decode, table.concat(vim.fn.readfile(pkg), "\n"))
    if ok and type(json) == "table" then
      for _, key in ipairs({ "dependencies", "devDependencies" }) do
        if type(json[key]) == "table" and json[key]["@slidev/cli"] ~= nil then
          return true
        end
      end
    end
  end
  return false
end

return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters = opts.formatters or {}
      local formatter = opts.formatters["markdownlint-cli2"] or {}
      -- LazyVim の markdown extra が設定した condition (markdownlint の診断があるときだけ整形) は残す
      local condition = formatter.condition
      formatter.condition = function(self, ctx)
        if is_slidev(ctx.dirname) then
          return false
        end
        return condition == nil or condition(self, ctx)
      end
      opts.formatters["markdownlint-cli2"] = formatter
    end,
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters = {
        ["markdownlint-cli2"] = {
          condition = function(ctx)
            return not is_slidev(ctx.dirname)
          end,
        },
      },
    },
  },
}
