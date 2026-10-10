import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register, Timer } from 'claude-code'

import type { Deck, Server } from '../types'

const PANE = 'slidev-preview'
const EMPTY: Deck = {
  path: '',
  outDir: '',
  slides: [],
  generation: 0,
  mtimeMs: 0,
  status: 'idle',
  error: '',
  start: 0,
}
const deck = atom({ plugin: 'slidev-preview', key: 'deck' } as const, EMPTY)
// Raster の変換が終わるたびに増やして、ペインを描き直す
const rasterTick = atom({ plugin: 'slidev-preview', key: 'rasterTick' } as const, 0)
const NO_SERVER: Server = { deckPath: '', taskId: '', url: '', status: 'stopped', error: '' }
const server = atom({ plugin: 'slidev-preview', key: 'server' } as const, NO_SERVER)

// export 中に再度変更されたら、終わった後にもう一度 export する
let isExporting = false
let isDirty = false

const dirOf = (path: string) => path.replace(/\/[^/]+$/, '')
const baseOf = (path: string) => path.split('/').pop() ?? path

export const outDirFor = (path: string) =>
  `/tmp/claude-slidev-preview/${path.replace(/^\//, '').replace(/[^A-Za-z0-9._-]/g, '_')}`

// slidev export --format png は 1.png, 2.png ... (または 01.png ...) を出力する
export const sortSlides = (names: string[]) =>
  names
    .filter(name => /^\d+\.png$/.test(name))
    .sort((a, b) => parseInt(a, 10) - parseInt(b, 10))

// /slidev の引数位置にあるトークンだけを補完する
export const isSlidevArg = (text: string, start: number) => /^\s*\/slidev\s+$/.test(text.slice(0, start))

// slides.md を先頭に、浅い階層・名前順で並べ、入力中の文字列を含むものに絞る
export const rankDecks = (files: string[], token: string) =>
  files
    .filter(file => file.toLowerCase().includes(token.toLowerCase()))
    .sort((a, b) => {
      const score = (f: string) => (baseOf(f) === 'slides.md' ? 0 : 1)
      return score(a) - score(b) || a.split('/').length - b.split('/').length || a.localeCompare(b)
    })
    .slice(0, 10)

let cachedFiles: { cwd: string; at: number; files: string[] } | undefined

const listMarkdown = async ($: EngineInterface, cwd: string) => {
  const now = await $.clock.now()
  if (cachedFiles?.cwd === cwd && now - cachedFiles.at < 5000) return cachedFiles.files
  const ran = await $.process.run(
    ['find', '.', '-maxdepth', '4', '-name', '*.md', '-not', '-path', '*/node_modules/*', '-not', '-path', '*/.*/*'],
    { cwd, timeoutMs: 3000 },
  )
  const files = ran.stdout
    .split('\n')
    .filter(Boolean)
    .map(file => file.replace(/^\.\//, ''))
  cachedFiles = { cwd, at: now, files }
  return files
}

// kitty / Ghostty は Image (画像プロトコル) で描く。それ以外 (WezTerm 等) は一度 Image を試し、
// $.ui.blit が断ってきたら (alt を描いている) セルで描く
let imageMode: 'image' | 'raster' | 'probe' = 'probe'
let isProbing = false
// セル表示にした理由 (ペインに薄く出す)
let imageReason = ''
let terminalName = ''

const detectImageSupport = async ($: EngineInterface) => {
  const ran = await $.process.run(['sh', '-c', 'printf "%s %s" "$TERM_PROGRAM" "$TERM"'])
  terminalName = ran.stdout.trim()
  imageMode = /ghostty|kitty/i.test(ran.stdout) ? 'image' : 'probe'
}

const probeImage = async ($: EngineInterface, key: string, file: string, columns: number, rows: number) => {
  if (isProbing) return
  isProbing = true
  try {
    await $.clock.sleep(300)
    const result = await $.ui.blit({ requestId: PANE, key, source: { file, format: 'png' }, columns, rows })
    imageMode = result.deny === undefined ? 'image' : 'raster'
    imageReason = result.deny ?? ''
  } catch (err) {
    imageMode = 'raster'
    imageReason = String(err)
  } finally {
    isProbing = false
    await update($, rasterTick, n => n + 1)
  }
}

// 1 セルを 2x2 の画素に分け、▘▝▖▗ 等の象限文字と前景・背景の 2 色で近似する
// mask の bit は 左上=1, 右上=2, 左下=4, 右下=8 (立っている画素が前景色)
const QUADRANTS = [
  0x2580, 0x2598, 0x259d, 0x2580, 0x2596, 0x258c, 0x259e, 0x259b,
  0x2597, 0x259a, 0x2590, 0x259c, 0x2584, 0x2599, 0x259f, 0x2588,
]

const readBmp = (bmp: Uint8Array) => {
  const view = new DataView(bmp.buffer, bmp.byteOffset, bmp.byteLength)
  const dataOffset = view.getUint32(10, true)
  const width = view.getInt32(18, true)
  const rawHeight = view.getInt32(22, true)
  const height = Math.abs(rawHeight)
  const bytesPerPixel = view.getUint16(28, true) / 8
  const stride = Math.floor((bytesPerPixel * 8 * width + 31) / 32) * 4
  return (x: number, y: number): [number, number, number] => {
    if (x >= width || y >= height) return [0, 0, 0]
    const row = rawHeight < 0 ? y : height - 1 - y
    const i = dataOffset + row * stride + x * bytesPerPixel
    return [bmp[i + 2] ?? 0, bmp[i + 1] ?? 0, bmp[i] ?? 0]
  }
}

const rgb = ([r, g, b]: number[]) => ((r ?? 0) << 16) | ((g ?? 0) << 8) | (b ?? 0)

// 画素は columns * 2 x rows * 2 必要。Raster の cells (codePoint, fg, bg の u32 LE) を返す
export const bmpToCells = (bmp: Uint8Array, columns: number, rows: number): Uint32Array => {
  const pixel = readBmp(bmp)
  const cells = new Uint32Array(columns * rows * 3)
  for (let y = 0; y < rows; y++) {
    for (let x = 0; x < columns; x++) {
      const px = [pixel(2 * x, 2 * y), pixel(2 * x + 1, 2 * y), pixel(2 * x, 2 * y + 1), pixel(2 * x + 1, 2 * y + 1)]
      // 補色の組は同じ分け方なので、右下が背景色になる 8 通りだけ試す
      let best = { error: Infinity, mask: 0, fg: [0, 0, 0], bg: [0, 0, 0] }
      for (let mask = 0; mask < 8; mask++) {
        const fg = [0, 0, 0]
        const bg = [0, 0, 0]
        let nf = 0
        px.forEach((p, i) => {
          const into = (mask >> i) & 1 ? fg : bg
          if ((mask >> i) & 1) nf++
          for (let c = 0; c < 3; c++) into[c] = (into[c] ?? 0) + (p[c] ?? 0)
        })
        const nb = 4 - nf
        for (let c = 0; c < 3; c++) {
          fg[c] = nf ? Math.round((fg[c] ?? 0) / nf) : 0
          bg[c] = Math.round((bg[c] ?? 0) / nb)
        }
        let error = 0
        px.forEach((p, i) => {
          const m = (mask >> i) & 1 ? fg : bg
          for (let c = 0; c < 3; c++) error += ((p[c] ?? 0) - (m[c] ?? 0)) ** 2
        })
        if (error < best.error) best = { error, mask, fg, bg }
      }
      const i = (y * columns + x) * 3
      // mask 0 は全面背景色。幅 1 の文字が要るので ▀ を前景も背景色にして描く
      cells[i] = QUADRANTS[best.mask] ?? 0x2580
      cells[i + 1] = rgb(best.mask === 0 ? best.bg : best.fg)
      cells[i + 2] = rgb(best.bg)
    }
  }
  return cells
}

const toBase64 = (words: Uint32Array) =>
  (new Uint8Array(words.buffer) as Uint8Array & { toBase64: () => string }).toBase64()
const fromBase64 = (base64: string) =>
  (Uint8Array as unknown as { fromBase64: (s: string) => Uint8Array }).fromBase64(base64)

// key: `${generation}:${slide}:${columns}` -> Raster の cells
const rasters = new Map<string, string>()
const converting = new Set<string>()
const rasterKey = (generation: number, name: string, columns: number) => `${generation}:${name}:${columns}`

const convertSlide = async ($: EngineInterface, current: Deck, name: string, columns: number, rows: number) => {
  const key = rasterKey(current.generation, name, columns)
  if (rasters.has(key) || converting.has(key)) return
  converting.add(key)
  try {
    const out = `${current.outDir}/raster-${columns}/${name.replace(/\.png$/, '.bmp')}`
    await $.process.run(['mkdir', '-p', dirOf(out)])
    await $.process.run(['sips', '-z', String(rows * 2), String(columns * 2), '-s', 'format', 'bmp', `${current.outDir}/${name}`, '--out', out])
    const { base64 } = await $.fs.read(out, { as: 'bytes' })
    rasters.set(key, toBase64(bmpToCells(fromBase64(base64), columns, rows)))
    await update($, rasterTick, n => n + 1)
  } finally {
    converting.delete(key)
  }
}

const exportDeck = async ($: EngineInterface): Promise<void> => {
  const current = await read($, deck)
  if (!current.path) return
  if (isExporting) {
    isDirty = true
    return
  }
  isExporting = true
  isDirty = false
  try {
    const stat = await $.fs.stat(current.path)
    await update($, deck, d => ({ ...d, status: 'exporting', error: '', mtimeMs: stat.mtimeMs }))
    // 書き出し中も前の画像を見せ続けるため、別のディレクトリに書き出して終わってから入れ替える
    const next = `${current.outDir}.next`
    await $.process.run(['rm', '-rf', next])
    // プロジェクトに入っている slidev を優先し、なければ npx で探す
    const local = `${dirOf(current.path)}/node_modules/.bin/slidev`
    const slidev = (await $.fs.exists(local)) ? [local] : ['npx', '--no-install', 'slidev']
    const ran = await $.process.run(
      [
        ...slidev,
        'export',
        baseOf(current.path),
        '--format',
        'png',
        '--output',
        next,
        '--timeout',
        '60000',
      ],
      { cwd: dirOf(current.path), timeoutMs: 300_000, env: { CI: '1' } },
    )
    const entries = await $.fs.list(next).catch(() => [])
    const slides = sortSlides(entries.filter(entry => entry.kind === 'file').map(entry => entry.name))
    if (ran.exitCode !== 0 || slides.length === 0) {
      await $.process.run(['rm', '-rf', next])
      const log = `${ran.stderr}\n${ran.stdout}`.trim().split('\n').slice(-8).join('\n')
      await update($, deck, d => ({ ...d, status: 'error', error: log || 'PNG が出力されませんでした。' }))
      return
    }
    const prev = `${current.outDir}.prev`
    await $.process.run(['sh', '-c', 'rm -rf "$2" && { [ ! -e "$1" ] || mv "$1" "$2"; } && mv "$3" "$1" && rm -rf "$2"', 'swap', current.outDir, prev, next])
    rasters.clear()
    await update($, deck, d => ({
      ...d,
      status: 'idle',
      slides,
      generation: d.generation + 1,
      start: Math.min(d.start, slides.length - 1),
    }))
  } catch (err) {
    await update($, deck, d => ({ ...d, status: 'error', error: String(err) }))
  } finally {
    isExporting = false
    if (isDirty) $.clock.after(0, () => void exportDeck($))
  }
}

// hook の dispatch から切り離して export する。編集が続くときは最後の編集から delay ms 待つ
const EDIT_DEBOUNCE_MS = 800
let pendingExport: Timer | undefined

const scheduleExport = ($: EngineInterface, delay = 0) => {
  pendingExport?.cancel()
  pendingExport = $.clock.after(delay, () => {
    pendingExport = undefined
    void exportDeck($)
  })
}

const followEdit = async ($: EngineInterface, filePath: string) => {
  const current = await read($, deck)
  if (current.path && filePath === current.path) scheduleExport($, EDIT_DEBOUNCE_MS)
}

// ---- ブラウザ用の dev サーバー (ghost で常駐させ、portless があれば https://<name>.localhost にする)

export const serverName = (deckPath: string) =>
  baseOf(dirOf(deckPath))
    .toLowerCase()
    .replace(/[^a-z0-9-]+/g, '-')
    .replace(/^-+|-+$/g, '') || 'slidev'

export const parseTaskId = (text: string) => text.match(/Task ID:\s*([0-9a-f-]{36})/)?.[1]

// portless のルート (https://<name>.localhost[:1355]) を優先し、なければ Slidev が出す localhost の URL
export const parseServerUrl = (log: string) =>
  log.match(/https?:\/\/[a-z0-9.-]+\.localhost(?::\d+)?/i)?.[0] ??
  log.match(/http:\/\/(?:localhost|127\.0\.0\.1):\d+/)?.[0]

const run = ($: EngineInterface, argv: string[], cwd?: string) =>
  $.process.run(argv, { cwd, timeoutMs: 15_000 }).catch(() => ({ exitCode: 1, stdout: '', stderr: '' }))

const isTaskRunning = async ($: EngineInterface, taskId: string) =>
  taskId !== '' && /Status:\s*running/.test((await run($, ['ghost', 'status', taskId])).stdout)

// 別セッションが同じデッキで起動したサーバーも拾って多重起動しない
const findRunningTask = async ($: EngineInterface, deckDir: string) => {
  const list = (await run($, ['ghost', 'list', '-s', 'running'])).stdout
  // Command 列は 30 文字で切れるので、portless 経由だと slidev が見えない。ディレクトリで判定する
  const line = list.split('\n').find(l => /slidev|portless/.test(l) && l.trimEnd().endsWith(deckDir))
  return line?.match(/^([0-9a-f-]{36})/)?.[1]
}

const hasPortless = async ($: EngineInterface) => (await run($, ['sh', '-c', 'command -v portless'])).exitCode === 0

// マシン再起動後はプロキシが落ちているので、sudo 不要の 1355 番で起こす
const ensurePortlessProxy = async ($: EngineInterface) => {
  if ((await run($, ['portless', 'list'])).exitCode === 0) return
  const list = (await run($, ['ghost', 'list', '-s', 'running'])).stdout
  if (!/portless proxy/.test(list)) await run($, ['ghost', 'run', '--', 'portless', 'proxy', 'start', '--port', '1355', '--https'])
  await $.clock.sleep(1500)
}

// 起動・ルート登録の確認は curl ではなく portless list とログで行う
const portlessUrl = async ($: EngineInterface, name: string) => {
  const list = await run($, ['portless', 'list'])
  if (list.exitCode !== 0 || !list.stdout.includes(`${name}.localhost`)) return undefined
  const got = await run($, ['portless', 'get', name])
  return got.exitCode === 0 ? parseServerUrl(got.stdout) : parseServerUrl(list.stdout)
}

const waitForUrl = async ($: EngineInterface, taskId: string, name?: string) => {
  for (let i = 0; i < 60; i++) {
    const log = (await run($, ['ghost', 'log', taskId])).stdout
    // portless 経由は Slidev のログにも localhost:<割当ポート> が出るので、ルートの登録を待つ
    const url = name ? await portlessUrl($, name) : parseServerUrl(log)
    if (url) return { url }
    if (!(await isTaskRunning($, taskId))) return { error: log.trim().split('\n').slice(-8).join('\n') || '起動に失敗しました。' }
    await $.clock.sleep(1000)
  }
  return { error: '60 秒待っても URL が出ませんでした。' }
}

const startServer = async ($: EngineInterface, deckPath: string) => {
  const deckDir = dirOf(deckPath)
  const current = await read($, server)
  if (current.status === 'starting') return
  if (current.deckPath === deckPath && current.url && (await isTaskRunning($, current.taskId))) {
    await run($, ['open', current.url])
    return
  }
  await update($, server, () => ({ ...NO_SERVER, deckPath, status: 'starting' }))
  try {
    const name = serverName(deckPath)
    const usePortless = await hasPortless($)
    if (usePortless) await ensurePortlessProxy($)
    let taskId = await findRunningTask($, deckDir)
    // 同名のルートがあれば (別セッションや手で起動したもの) それを開く
    const existing = usePortless ? await portlessUrl($, name) : undefined
    if (existing) {
      await update($, server, s => ({ ...s, taskId: taskId ?? '', url: existing, status: 'running' }))
      await run($, ['open', existing])
      return
    }
    if (!taskId) {
      const local = `${deckDir}/node_modules/.bin/slidev`
      const slidev = (await $.fs.exists(local)) ? local : 'npx --no-install slidev'
      // Slidev は PORT を読まないので --port で渡す。portless は IPv4 に繋ぐので 127.0.0.1 で待ち受ける
      const dev = `${slidev} ${JSON.stringify(baseOf(deckPath))} --port \${PORT:-3030} --remote --bind 127.0.0.1`
      const argv = usePortless ? ['portless', name, 'sh', '-c', dev] : ['sh', '-c', dev]
      const started = await run($, ['ghost', 'run', '-c', deckDir, '--', ...argv])
      taskId = parseTaskId(started.stdout)
      if (!taskId) throw new Error(`ghost run に失敗しました: ${started.stderr || started.stdout}`)
    }
    const found = await waitForUrl($, taskId, usePortless ? name : undefined)
    if (!found.url) {
      await update($, server, s => ({ ...s, taskId: taskId ?? '', status: 'error', error: found.error ?? '' }))
      return
    }
    await update($, server, s => ({ ...s, taskId: taskId ?? '', url: found.url ?? '', status: 'running' }))
    await run($, ['open', found.url])
  } catch (err) {
    await update($, server, s => ({ ...s, status: 'error', error: String(err) }))
  }
}

// ghost list の行のうち、slidev の dev サーバーのもの (portless のプロキシは残す)
export const slidevTaskLines = (list: string) =>
  list
    .split('\n')
    .filter(l => /^[0-9a-f-]{36}\s/.test(l) && /slidev|portless/.test(l) && !/portless proxy/.test(l))

const stopTask = async ($: EngineInterface, taskId: string) => (await run($, ['ghost', 'stop', taskId])).exitCode === 0

// 指定したデッキのサーバーを止める。別セッションで起動したものも ghost list から探す
const stopServer = async ($: EngineInterface, deckPath?: string) => {
  const current = await read($, server)
  const path = deckPath ?? current.deckPath
  const taskId =
    (current.deckPath === path && current.taskId) || (path ? await findRunningTask($, dirOf(path)) : undefined)
  const stopped = taskId ? await stopTask($, taskId) : false
  if (!deckPath || current.deckPath === path) await update($, server, () => NO_SERVER)
  return stopped
}

const stopAllServers = async ($: EngineInterface) => {
  const lines = slidevTaskLines((await run($, ['ghost', 'list', '-s', 'running'])).stdout)
  let count = 0
  for (const line of lines) {
    const taskId = line.slice(0, 36)
    if (await stopTask($, taskId)) count++
  }
  await update($, server, () => NO_SERVER)
  return count
}

const scheduleServer = ($: EngineInterface, deckPath: string) => {
  $.clock.after(0, () => void startServer($, deckPath))
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'slidev',
      description: 'Preview a Slidev deck as images in a pane',
      argumentHint: '[path/to/slides.md]',
    })
    await $.command.register({
      name: 'slidev-browser',
      description: 'Serve a Slidev deck with ghost (+ portless) and open it in the browser',
      argumentHint: '[path/to/slides.md]',
    })
    await $.command.register({
      name: 'slidev-stop',
      description: 'Stop the Slidev dev server started by /slidev-browser',
      argumentHint: '[path/to/slides.md | all]',
    })
    await detectImageSupport($).catch(() => undefined)
    // エディタ等、Claude 以外による編集も拾う
    $.clock.every(2000, async () => {
      const current = await read($, deck)
      if (!current.path || isExporting) return
      const stat = await $.fs.stat(current.path).catch(() => undefined)
      if (stat && stat.mtimeMs !== current.mtimeMs) scheduleExport($, EDIT_DEBOUNCE_MS)
    })

    return next(e)
  })

  on('command.run', { command: 'slidev' }, async ($, e) => {
    const arg = e.args.trim() || 'slides.md'
    const cwd = await $.session.cwd()
    const path = arg.startsWith('/') ? arg : `${cwd}/${arg}`
    if (!(await $.fs.exists(path))) return { text: `${path} がありません。` }
    const current = await read($, deck)
    if (current.path !== path) {
      await update($, deck, () => ({ ...EMPTY, path, outDir: outDirFor(path) }))
    }
    await $.ui.open({ id: PANE, title: 'Slidev' })
    scheduleExport($)

    return { text: `${baseOf(path)} を Slidev Preview で開きました (export 中…)。` }
  })

  on('command.run', { command: 'slidev-browser' }, async ($, e) => {
    const arg = e.args.trim() || (await read($, deck)).path || 'slides.md'
    const cwd = await $.session.cwd()
    const path = arg.startsWith('/') ? arg : `${cwd}/${arg}`
    if (!(await $.fs.exists(path))) return { text: `${path} がありません。` }
    scheduleServer($, path)
    return { text: `${baseOf(path)} の dev サーバーを ghost で起動し、ブラウザで開きます…` }
  })

  on('command.run', { command: 'slidev-stop' }, async ($, e) => {
    const arg = e.args.trim()
    if (arg === 'all') {
      const count = await stopAllServers($)
      return { text: count ? `Slidev の dev サーバーを ${count} 個止めました。` : '動いている Slidev の dev サーバーはありません。' }
    }
    const cwd = await $.session.cwd()
    const path = arg ? (arg.startsWith('/') ? arg : `${cwd}/${arg}`) : (await read($, server)).deckPath || (await read($, deck)).path
    if (!path) return { text: '止めるデッキを指定してください (/slidev-stop slides.md か all)。' }
    return { text: (await stopServer($, path)) ? `${baseOf(path)} の dev サーバーを止めました。` : `${path} の dev サーバーは動いていません。` }
  })

  on('tool.call', { tool: 'Edit' }, async ($, e, next) => {
    const ran = await next(e)
    if (ran.deny === undefined && ran.isError !== true) await followEdit($, e.file_path).catch(() => undefined)
    return ran
  })
  on('tool.call', { tool: 'Write' }, async ($, e, next) => {
    const ran = await next(e)
    if (ran.deny === undefined && ran.isError !== true) await followEdit($, e.file_path).catch(() => undefined)
    return ran
  })

  on('prompt.autocomplete', async ($, e, next) => {
    const ran = await next(e)
    if (!isSlidevArg(e.text, e.start) && !/^\s*\/slidev-(?:browser|stop)\s+$/.test(e.text.slice(0, e.start))) return ran
    const files = await listMarkdown($, await $.session.cwd()).catch(() => [])
    const mine = rankDecks(files, e.token).map(file => ({ text: file, description: 'Slidev deck' }))
    return { suggestions: [...mine, ...ran.suggestions] }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button, Image, Raster } = $.ui.resolve(e)
    const current = await read($, deck)
    const web = await read($, server)
    await read($, rasterTick)
    if (!current.path) return <Text dimColor>/slidev [slides.md] でデッキを開いてください。</Text>

    const total = current.slides.length
    // ペインの本文幅いっぱいに描く
    const columns = Math.max(20, Math.min(200, e.props.bodyColumns || Math.floor((e.viewport?.columns ?? 160) * 0.45)))
    // セルは縦横比 おおよそ 1:2 なので 16:9 のスライドは columns * 9/32 行
    const rows = Math.max(5, Math.round((columns * 9) / 32))
    // 見えている枚数だけ描く
    const visible = Math.max(1, Math.ceil((e.viewport?.rows ?? 40) / (rows + 1)))
    const shown = current.slides.slice(current.start, current.start + visible)
    const move = (delta: number) =>
      update($, deck, d => ({ ...d, start: Math.max(0, Math.min(total - 1, d.start + delta)) }))
    const status =
      current.status === 'exporting' ? 'exporting…' : current.status === 'error' ? 'error' : ''

    const slide = (name: string, index: number) => {
      if (imageMode !== 'raster') {
        if (imageMode === 'probe') {
          const file = `${current.outDir}/${name}`
          $.clock.after(0, () => void probeImage($, `slide-${index}`, file, columns, rows))
        }
        return (
          <Image
            key={`slide-${index}`}
            source={{ file: `${current.outDir}/${name}`, format: 'png', generation: current.generation }}
            columns={columns}
            rows={rows}
            alt={`slide ${index + 1}`}
          />
        )
      }
      const cells = rasters.get(rasterKey(current.generation, name, columns))
      if (!cells) {
        $.clock.after(0, () => void convertSlide($, current, name, columns, rows).catch(() => undefined))
        return <Text dimColor>変換中…</Text>
      }
      return <Raster key={`slide-${index}`} columns={columns} rows={rows} cells={cells} />
    }

    return (
      <Box flexDirection="column">
        <Box flexDirection="row" gap={1}>
          <Text bold>{baseOf(current.path)}</Text>
          <Text dimColor>{total} slides</Text>
          <Button label="Prev" hotkey="k" plain onPress={() => move(-1)} />
          <Button label="Next" hotkey="j" plain onPress={() => move(1)} />
          <Button label="Reload" hotkey="r" plain onPress={() => scheduleExport($)} />
          <Button label="Browser" hotkey="b" plain onPress={() => scheduleServer($, current.path)} />
          {web.status !== 'stopped' && <Button label="Stop" hotkey="s" plain onPress={() => void stopServer($)} />}
          {status && <Text color={current.status === 'error' ? 'red' : 'yellow'}>{status}</Text>}
        </Box>
        {web.status === 'starting' && <Text color="yellow">dev サーバーを起動中…</Text>}
        {web.status === 'running' && <Text color="green">{web.url}</Text>}
        {web.status === 'error' && <Text color="red">{web.error}</Text>}
        {imageMode === 'raster' && (
          <Text dimColor wrap="truncate-end">
            セル表示 ({terminalName || '?'}): {imageReason || '画像を描けません'}
          </Text>
        )}
        {current.status === 'error' && <Text color="red">{current.error}</Text>}
        {total === 0 && current.status !== 'error' && <Text dimColor>export 中…</Text>}
        {shown.map((name, i) => (
          <Box flexDirection="column">
            <Text dimColor>
              {current.start + i + 1} / {total}
            </Text>
            {slide(name, current.start + i)}
          </Box>
        ))}
      </Box>
    )
  })
}
