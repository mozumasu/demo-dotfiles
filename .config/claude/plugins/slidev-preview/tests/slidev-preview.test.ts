import { expect, test } from 'claude-code/testing'

import { bmpToCells, isSlidevArg, outDirFor, parseServerUrl, parseTaskId, rankDecks, serverName, slidevTaskLines, sortSlides } from '../hooks/register'

test('sortSlides keeps numbered PNGs in slide order', async () => {
  expect(sortSlides(['10.png', '2.png', '1.png', 'notes.txt', 'a.png'])).toEqual(['1.png', '2.png', '10.png'])
  expect(sortSlides(['002.png', '001.png'])).toEqual(['001.png', '002.png'])
})

test('outDirFor maps a deck path to a flat tmp directory', async () => {
  expect(outDirFor('/Users/me/my slides/slides.md')).toBe('/tmp/claude-slidev-preview/Users_me_my_slides_slides.md')
})

test('isSlidevArg matches only the argument of /slidev', async () => {
  expect(isSlidevArg('/slidev sl', 8)).toBe(true)
  expect(isSlidevArg('/slidevx sl', 9)).toBe(false)
  expect(isSlidevArg('hello sl', 6)).toBe(false)
  expect(isSlidevArg('/slidev a b', 10)).toBe(false)
})

test('rankDecks puts slides.md first and filters by token', async () => {
  expect(rankDecks(['docs/a.md', 'talk/slides.md', 'README.md', 'slides.md'], 'md')).toEqual([
    'slides.md',
    'talk/slides.md',
    'README.md',
    'docs/a.md',
  ])
  expect(rankDecks(['talk/slides.md', 'README.md'], 'talk')).toEqual(['talk/slides.md'])
})

test('bmpToCells picks a quadrant glyph and two colors per 2x2 block', async () => {
  // 2x2, 24bit, top-down の BMP。左上だけ赤、残りは白
  const bmp = new Uint8Array(54 + 16)
  const view = new DataView(bmp.buffer)
  view.setUint32(10, 54, true)
  view.setInt32(18, 2, true)
  view.setInt32(22, -2, true)
  view.setUint16(28, 24, true)
  bmp.set([0, 0, 255, 255, 255, 255, 0, 0], 54)
  bmp.set([255, 255, 255, 255, 255, 255, 0, 0], 62)
  expect(Array.from(bmpToCells(bmp, 1, 1))).toEqual([0x2598, 0xff0000, 0xffffff])
})

test('bmpToCells draws a flat block with fg equal to bg', async () => {
  const bmp = new Uint8Array(54 + 16).fill(0x80, 54)
  const view = new DataView(bmp.buffer)
  view.setUint32(10, 54, true)
  view.setInt32(18, 2, true)
  view.setInt32(22, -2, true)
  view.setUint16(28, 24, true)
  expect(Array.from(bmpToCells(bmp, 1, 1))).toEqual([0x2580, 0x808080, 0x808080])
})

test('serverName slugs the deck directory', async () => {
  expect(serverName('/x/slides/2026-10-terminal-night-3/slides.md')).toBe('2026-10-terminal-night-3')
  expect(serverName('/x/My Talk!/slides.md')).toBe('my-talk')
})

test('parseServerUrl prefers the portless route', async () => {
  expect(parseServerUrl('-> https://talk.localhost:1355\n  http://localhost:4123/')).toBe('https://talk.localhost:1355')
  expect(parseServerUrl('  public slide show   > http://localhost:3030/')).toBe('http://localhost:3030')
  expect(parseServerUrl('starting...')).toBeUndefined()
})

test('parseTaskId reads ghost run output', async () => {
  expect(parseTaskId('Started background process:\n  Task ID: 55c32b75-8813-4721-abb3-fd2adc2af1bc\n')).toBe(
    '55c32b75-8813-4721-abb3-fd2adc2af1bc',
  )
})

test('slidevTaskLines keeps dev servers and skips the portless proxy', async () => {
  const list = [
    'Task ID                              PID      Status     Started              Command                        Directory',
    '----------',
    '11111111-1111-1111-1111-111111111111 1        running    2026-10-10 06:42     portless 2026-10-terminal-ni   /x/talk',
    '22222222-2222-2222-2222-222222222222 2        running    2026-10-10 06:42     portless proxy start --port 13 /x',
    '33333333-3333-3333-3333-333333333333 3        running    2026-10-10 06:42     sleep 30                       /tmp',
  ].join('\n')
  expect(slidevTaskLines(list).map(l => l.slice(0, 8))).toEqual(['11111111'])
})
