-- prettier は Slidev のスライドごとの frontmatter (--- で挟んだ layout: 等) を見出しや水平線として書き換えてしまう。
-- LazyVim の markdown extra は node_modules の prettier でも整形するので、prettier の設定ファイルがあるプロジェクトでだけ使う
-- (LazyVim の formatting.prettier extra の vim.g.lazyvim_prettier_needs_config = true と同じ挙動)
local config_files = {
  ".prettierrc",
  ".prettierrc.json",
  ".prettierrc.yml",
  ".prettierrc.yaml",
  ".prettierrc.json5",
  ".prettierrc.js",
  ".prettierrc.cjs",
  ".prettierrc.mjs",
  ".prettierrc.ts",
  ".prettierrc.cts",
  ".prettierrc.mts",
  ".prettierrc.toml",
  "prettier.config.js",
  "prettier.config.cjs",
  "prettier.config.mjs",
  "prettier.config.ts",
  "prettier.config.cts",
  "prettier.config.mts",
}

---@param dir string
local function has_config(dir)
  if #vim.fs.find(config_files, { upward = true, path = dir, limit = 1 }) > 0 then
    return true
  end
  -- package.json の "prettier" キーでも設定できる
  for _, pkg in ipairs(vim.fs.find("package.json", { upward = true, path = dir, limit = math.huge })) do
    local ok, json = pcall(vim.json.decode, table.concat(vim.fn.readfile(pkg), "\n"))
    if ok and type(json) == "table" and json.prettier ~= nil then
      return true
    end
  end
  return false
end

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters = {
        prettier = {
          condition = function(_, ctx)
            return has_config(ctx.dirname)
          end,
        },
      },
    },
  },
}
