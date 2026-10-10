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

-- treesitter の markdown は見出し単位でしか折りたためないので、Slidev のスライド単位で折りたたむ。
-- スライドは区切りの --- から次の区切りの手前まで。frontmatter の閉じの --- とコードブロック内の --- は区切りとみなさない。
-- 区切りの --- の行には render-markdown が区切り線を overlay で重ねて foldtext を隠してしまうので、
-- 区切りの行は折りたたまずに残し、その次の行から折りたたむ

---@class SlidevSlide
---@field index integer 何枚目のスライドか
---@field start integer スライドの先頭行 (1-based)。区切りの --- があればその行
---@field fold_start integer 折りたたみの先頭行。区切りの --- の次の行
---@field title? string 閉じたときに表示する名前。frontmatter の title > 見出し > 最初の本文の順で選ぶ
---@field heading? string スライド内の最初の見出し (# / ## …)
---@field fm_title? string frontmatter の title
---@field text? string 最初の本文 (HTML タグは除く)

---@type table<integer, { tick: integer, slides: SlidevSlide[], folds: table<integer, SlidevSlide>, separators: table<integer, true> }>
local slide_cache = {}

---@param buf integer
local function parse_slides(buf)
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local cache = slide_cache[buf]
  if cache and cache.tick == tick then
    return cache
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local slides = {} ---@type SlidevSlide[]
  local fence ---@type string?
  local i = 1

  ---@param start integer
  local function add_slide(start)
    local slide = { index = #slides + 1, start = start, fold_start = start }
    slides[#slides + 1] = slide
    -- 区切りの直後に --- までの key: value が続けば frontmatter として読み飛ばす
    local separator = lines[start] ~= nil and lines[start]:match("^%-%-%-%s*$") ~= nil
    if separator then
      slide.fold_start = start + 1
    end
    if separator and (lines[start + 1] or ""):match("^[%w_-]+:") then
      for j = start + 1, #lines do
        if lines[j]:match("^%-%-%-%s*$") then
          i = j
          break
        end
        slide.fm_title = slide.fm_title or lines[j]:match("^title:%s*(.-)%s*$")
      end
    end
  end

  add_slide(1)
  i = i + 1
  while i <= #lines do
    local line = lines[i]
    local marker = line:match("^%s*([`~][`~][`~]+)")
    if fence then
      if marker and marker:sub(1, 1) == fence:sub(1, 1) and #marker >= #fence then
        fence = nil
      end
    elseif marker then
      fence = marker
    elseif line:match("^%-%-%-%s*$") then
      add_slide(i)
    else
      local slide = slides[#slides]
      slide.heading = slide.heading or line:match("^#+%s+(.-)%s*$")
      if not slide.text then
        local text = vim.trim((line:gsub("<[^>]*>", " "):gsub("%s+", " ")))
        slide.text = text ~= "" and text or nil
      end
    end
    i = i + 1
  end

  local folds = {} ---@type table<integer, SlidevSlide>
  local separators = {} ---@type table<integer, true>
  for _, slide in ipairs(slides) do
    slide.title = slide.fm_title or slide.heading or slide.text or ("Slide " .. slide.index)
    folds[slide.fold_start] = slide
    if slide.fold_start ~= slide.start then
      separators[slide.start] = true
    end
  end
  cache = { tick = tick, slides = slides, folds = folds, separators = separators }
  slide_cache[buf] = cache
  return cache
end

function _G.slidev_foldexpr()
  local cache = parse_slides(vim.api.nvim_get_current_buf())
  if cache.separators[vim.v.lnum] then
    return "0"
  end
  return cache.folds[vim.v.lnum] and ">1" or "1"
end

function _G.slidev_foldtext()
  local slide = parse_slides(vim.api.nvim_get_current_buf()).folds[vim.v.foldstart]
  return {
    { ("%d. "):format(slide and slide.index or 0), "Number" },
    { slide and slide.title or "", "Title" },
    { ("  (%d lines)"):format(vim.v.foldend - vim.v.foldstart + 1), "Comment" },
  }
end

-- スライドの一覧を picker で出し、選んだスライドへジャンプする。最初はカーソルのあるスライドを選んだ状態で開く
---@param buf integer
local function pick_slides(buf)
  local slides = parse_slides(buf).slides
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  local last = vim.api.nvim_buf_line_count(buf)
  local file = vim.api.nvim_buf_get_name(buf)
  local items = {} ---@type snacks.picker.finder.Item[]
  local current = 1
  for _, slide in ipairs(slides) do
    if slide.start <= cursor then
      current = slide.index
    end
    items[#items + 1] = {
      text = ("%d %s"):format(slide.index, slide.title),
      slide = slide,
      buf = buf,
      file = file,
      pos = { math.min(slide.fold_start, last), 0 },
    }
  end
  Snacks.picker.pick({
    title = "Slides",
    items = items,
    format = function(item)
      return {
        { ("%3d. "):format(item.slide.index), "Number" },
        { item.slide.title, "Title" },
      }
    end,
    sort = { fields = { "score:desc", "idx" } },
    on_show = function(picker)
      picker.list:view(current)
    end,
  })
end

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("slidev_fold", { clear = true }),
  pattern = "markdown",
  callback = function(ev)
    if not is_slidev(vim.fs.dirname(vim.api.nvim_buf_get_name(ev.buf))) then
      return
    end
    vim.opt_local.foldmethod = "expr"
    vim.opt_local.foldexpr = "v:lua.slidev_foldexpr()"
    vim.opt_local.foldtext = "v:lua.slidev_foldtext()"
    vim.keymap.set("n", "<localleader>s", function()
      pick_slides(ev.buf)
    end, { buffer = ev.buf, desc = "Slidev Slides" })
    vim.api.nvim_create_autocmd("BufWipeout", {
      buffer = ev.buf,
      once = true,
      callback = function()
        slide_cache[ev.buf] = nil
      end,
    })
  end,
})

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
            if is_slidev(ctx.dirname) then
              return false
            end
            -- stdin で lint するため設定ファイルは nvim の cwd からしか探されない。
            -- 編集中ファイルから上に辿って見つかった設定ファイルのディレクトリで実行する
            local config = vim.fs.find({
              ".markdownlint-cli2.jsonc",
              ".markdownlint-cli2.yaml",
              ".markdownlint-cli2.cjs",
              ".markdownlint-cli2.mjs",
              ".markdownlint.jsonc",
              ".markdownlint.json",
              ".markdownlint.yaml",
              ".markdownlint.yml",
              ".markdownlint.cjs",
              ".markdownlint.mjs",
            }, { upward = true, path = ctx.dirname })[1]
            require("lint").linters["markdownlint-cli2"].cwd = config and vim.fs.dirname(config) or nil
            return true
          end,
        },
      },
    },
  },
}
