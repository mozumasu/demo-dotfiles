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
---@field src? string frontmatter の src。このスライドは別ファイルのスライドに置き換わる

---@alias SlidevParsed { tick?: integer, slides: SlidevSlide[], folds: table<integer, SlidevSlide>, separators: table<integer, true> }

---@type table<integer, SlidevParsed>
local slide_cache = {}

---@param lines string[]
---@return SlidevParsed
local function parse_lines(lines)
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
        slide.fm_title = slide.fm_title or lines[j]:match("^title:%s*[\"']?(.-)[\"']?%s*$")
        slide.src = slide.src or lines[j]:match("^src:%s*[\"']?(.-)[\"']?%s*$")
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
    slide.title = slide.fm_title or slide.heading or slide.text or slide.src or ("Slide " .. slide.index)
    folds[slide.fold_start] = slide
    if slide.fold_start ~= slide.start then
      separators[slide.start] = true
    end
  end
  return { slides = slides, folds = folds, separators = separators }
end

---@param buf integer
local function parse_slides(buf)
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local cache = slide_cache[buf]
  if cache and cache.tick == tick then
    return cache
  end
  cache = parse_lines(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  cache.tick = tick
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

-- src: で読み込むファイルのパス。読み込むスライドを絞る #2,5-6 のような指定は外す
---@param file string src を書いたファイル
---@param src string
local function resolve_src(file, src)
  return vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(file), (src:gsub("#.*$", ""))))
end

-- 開いているファイルは保存前の内容を使う
---@param file string
---@return string[]?
local function file_lines(file)
  local buf = vim.fn.bufnr(file)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end
  local ok, lines = pcall(vim.fn.readfile, file)
  return ok and lines or nil
end

-- src: を辿って、デッキ全体のスライドを Slidev が並べる順に集める
---@param file string
---@param out { file: string, slide: SlidevSlide, last: integer }[]
---@param stack table<string, true> 読み込み中のファイル。循環した src を辿らないために使う
local function collect_deck(file, out, stack)
  local lines = not stack[file] and file_lines(file)
  if not lines then
    return out
  end
  stack[file] = true
  for _, slide in ipairs(parse_lines(lines).slides) do
    if slide.src then
      collect_deck(resolve_src(file, slide.src), out, stack)
    else
      out[#out + 1] = { file = file, slide = slide, last = #lines }
    end
  end
  stack[file] = nil
  return out
end

-- カーソルのあるスライドが src: で別ファイルを読み込んでいれば、そのファイルを開く
---@return boolean 開いたかどうか
local function goto_src()
  local buf = vim.api.nvim_get_current_buf()
  if not vim.b[buf].slidev then
    return false
  end
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  local current ---@type SlidevSlide?
  for _, slide in ipairs(parse_slides(buf).slides) do
    if slide.start <= cursor then
      current = slide
    end
  end
  if not (current and current.src) then
    return false
  end
  vim.cmd.edit(vim.fn.fnameescape(resolve_src(vim.api.nvim_buf_get_name(buf), current.src)))
  return true
end

-- スライドの一覧を picker で出し、選んだスライドへジャンプする。最初はカーソルのあるスライドを選んだ状態で開く。
-- src: で分割したデッキは、分割先のファイルから開いても slides.md から辿った全体を出す
---@param buf integer
local function pick_slides(buf)
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  local file = vim.fs.normalize(vim.api.nvim_buf_get_name(buf))
  local entry = vim.fs.find("slides.md", { upward = true, path = vim.fs.dirname(file) })[1]
  local deck = entry and collect_deck(vim.fs.normalize(entry), {}, {}) or {}
  local in_deck = vim.iter(deck):any(function(d)
    return d.file == file
  end)
  if not in_deck then
    deck = collect_deck(file, {}, {})
  end

  local items = {} ---@type snacks.picker.finder.Item[]
  local current = 1
  local multi = false
  for index, d in ipairs(deck) do
    if d.file == file and d.slide.start <= cursor then
      current = index
    end
    multi = multi or d.file ~= deck[1].file
    items[#items + 1] = {
      text = ("%d %s"):format(index, d.slide.title),
      index = index,
      title = d.slide.title,
      buf = d.file == file and buf or nil,
      file = d.file,
      pos = { math.min(d.slide.fold_start, d.last), 0 },
    }
  end
  Snacks.picker.pick({
    title = "Slides",
    items = items,
    format = function(item)
      return {
        { ("%3d. "):format(item.index), "Number" },
        { item.title, "Title" },
        { multi and ("  " .. vim.fs.basename(item.file)) or "", "Comment" },
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
    vim.b[ev.buf].slidev = true
    vim.opt_local.foldmethod = "expr"
    vim.opt_local.foldexpr = "v:lua.slidev_foldexpr()"
    vim.opt_local.foldtext = "v:lua.slidev_foldtext()"
    vim.keymap.set("n", "<localleader>s", function()
      pick_slides(ev.buf)
    end, { buffer = ev.buf, desc = "Slidev Slides" })
    -- LSP が付くと LazyVim の gd に上書きされるので、そちらは下の nvim-lspconfig の keys で同じ動きにする
    vim.keymap.set("n", "gd", function()
      if not goto_src() then
        vim.cmd("normal! gd")
      end
    end, { buffer = ev.buf, desc = "Goto Definition / Slidev src" })
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
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ["*"] = {
          keys = {
            {
              "gd",
              function()
                if not goto_src() then
                  Snacks.picker.lsp_definitions()
                end
              end,
              desc = "Goto Definition",
              has = "definition",
            },
          },
        },
      },
    },
  },
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
