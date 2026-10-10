export type Deck = {
  path: string
  outDir: string
  slides: string[]
  generation: number
  mtimeMs: number
  status: 'idle' | 'exporting' | 'error'
  error: string
  start: number
}

declare module 'claude-code' {
  interface PluginState {
    'slidev-preview': { deck: Deck; rasterTick: number }
  }
}
