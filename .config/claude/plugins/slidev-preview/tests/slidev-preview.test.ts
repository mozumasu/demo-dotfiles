import { expect, test } from 'claude-code/testing'

import { bmpToCells, isSlidevArg, outDirFor, rankDecks, sortSlides } from '../hooks/register'

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
