// Gmail フィルタ定義 (gmailctl)
// 反映: gmailctl diff で確認してから gmailctl apply
// 注意: apply は Gmail 側のフィルタをこの内容で上書きする (ここにないフィルタは削除される)

// 届いた時点で既読 + 受信トレイをスキップするメール
local autoRead = [
  // { from: 'noreply@example.com' },
  // { list: 'newsletter.example.com' },
];

local rules = [
  {
    filter: { or: autoRead },
    actions: { markRead: true, archive: true, labels: ['auto-read'] },
  },
];

{
  version: 'v1alpha3',
  rules: if std.length(autoRead) > 0 then rules else [],
  labels: [{ name: 'auto-read' }],
}
