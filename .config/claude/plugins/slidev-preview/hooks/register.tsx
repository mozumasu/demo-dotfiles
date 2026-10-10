import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Deck } from '../types'

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
    await $.process.run(['rm', '-rf', current.outDir])
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
        current.outDir,
        '--timeout',
        '60000',
      ],
      { cwd: dirOf(current.path), timeoutMs: 300_000, env: { CI: '1' } },
    )
    const entries = await $.fs.list(current.outDir).catch(() => [])
    const slides = sortSlides(entries.filter(entry => entry.kind === 'file').map(entry => entry.name))
    if (ran.exitCode !== 0 || slides.length === 0) {
      const log = `${ran.stderr}\n${ran.stdout}`.trim().split('\n').slice(-8).join('\n')
      await update($, deck, d => ({ ...d, status: 'error', error: log || 'PNG が出力されませんでした。' }))
      return
    }
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

// hook の dispatch から切り離して export する
const scheduleExport = ($: EngineInterface) => {
  $.clock.after(0, () => void exportDeck($))
}

const followEdit = async ($: EngineInterface, filePath: string) => {
  const current = await read($, deck)
  if (current.path && filePath === current.path) scheduleExport($)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'slidev',
      description: 'Preview a Slidev deck as images in a pane',
      argumentHint: '[path/to/slides.md]',
    })
    // エディタ等、Claude 以外による編集も拾う
    $.clock.every(2000, async () => {
      const current = await read($, deck)
      if (!current.path || isExporting) return
      const stat = await $.fs.stat(current.path).catch(() => undefined)
      if (stat && stat.mtimeMs !== current.mtimeMs) scheduleExport($)
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
    if (!isSlidevArg(e.text, e.start)) return ran
    const files = await listMarkdown($, await $.session.cwd()).catch(() => [])
    const mine = rankDecks(files, e.token).map(file => ({ text: file, description: 'Slidev deck' }))
    return { suggestions: [...mine, ...ran.suggestions] }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button, Image } = $.ui.resolve(e)
    const current = await read($, deck)
    if (!current.path) return <Text dimColor>/slidev [slides.md] でデッキを開いてください。</Text>

    const total = current.slides.length
    const columns = Math.max(20, Math.min(120, Math.floor((e.viewport?.columns ?? 160) * 0.45)))
    // セルは縦横比 おおよそ 1:2 なので 16:9 のスライドは columns * 9/32 行
    const rows = Math.max(5, Math.round((columns * 9) / 32))
    const move = (delta: number) =>
      update($, deck, d => ({ ...d, start: Math.max(0, Math.min(total - 1, d.start + delta)) }))
    const status =
      current.status === 'exporting' ? 'exporting…' : current.status === 'error' ? 'error' : ''

    return (
      <Box flexDirection="column">
        <Box flexDirection="row" gap={1}>
          <Text bold>{baseOf(current.path)}</Text>
          <Text dimColor>{total} slides</Text>
          <Button label="Prev" hotkey="k" plain onPress={() => move(-1)} />
          <Button label="Next" hotkey="j" plain onPress={() => move(1)} />
          <Button label="Reload" hotkey="r" plain onPress={() => scheduleExport($)} />
          {status && <Text color={current.status === 'error' ? 'red' : 'yellow'}>{status}</Text>}
        </Box>
        {current.status === 'error' && <Text color="red">{current.error}</Text>}
        {total === 0 && current.status !== 'error' && <Text dimColor>export 中…</Text>}
        {current.slides.slice(current.start).map((name, i) => (
          <Box flexDirection="column">
            <Text dimColor>
              {current.start + i + 1} / {total}
            </Text>
            <Image
              key={`slide-${current.start + i}`}
              source={{ file: `${current.outDir}/${name}`, format: 'png', generation: current.generation }}
              columns={columns}
              rows={rows}
              alt={`slide ${current.start + i + 1}`}
            />
          </Box>
        ))}
      </Box>
    )
  })
}
