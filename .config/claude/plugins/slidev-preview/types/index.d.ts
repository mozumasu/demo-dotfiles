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

export type Server = {
  deckPath: string
  taskId: string
  url: string
  status: 'stopped' | 'starting' | 'running' | 'error'
  error: string
}

declare module 'claude-code' {
  interface PluginState {
    'slidev-preview': { deck: Deck; rasterTick: number; server: Server }
  }
}
