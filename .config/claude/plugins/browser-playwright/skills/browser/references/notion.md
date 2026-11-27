# Notion をブラウザで扱う

## ワークスペースを検索する

ページの中から内部の API を呼ぶと、ワークスペースの中を検索できる。claude.ai の Notion MCP が別のワークスペースにつながっていて見つからないときに使う。

```js
async () => {
  // spaceId は、ワークスペース内のどれかのページの ID から引く
  const { spaceId } = await fetch('/api/v3/getPublicPageData', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ type: 'block-space', name: 'page', blockId: '<ページ ID>', requestedOnPublicDomain: false }),
  }).then(r => r.json());
  const res = await fetch('/api/v3/search', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      type: 'BlocksInSpace', query: '<検索語>', spaceId, limit: 20, sort: { field: 'relevance' }, source: 'quick_find',
      filters: { isDeletedOnly: false, excludeTemplates: false, navigableBlockContentOnly: false, requireEditPermissions: false,
        ancestors: [], createdBy: [], editedBy: [], lastEditedTime: {}, createdTime: {}, inTeams: [] },
    }),
  }).then(r => r.json());
  return res.results.map(r => ({ id: r.id, text: r.highlight?.text, path: r.highlight?.pathText }));
}
```

## 長いページの中の要素を探す

本文のスクロール領域は `.notion-frame .notion-scroller.vertical`。画面に入ったブロックしか描画されないので、少しずつスクロールしながら探す。

```js
async () => {
  const s = document.querySelector('.notion-frame .notion-scroller.vertical');
  for (let i = 0; i < 60; i++) {
    const el = [...document.querySelectorAll('.notion-page-content [data-block-id]')]
      .find(e => (e.innerText || '').trim() === '<探す文字列>');
    if (el) { el.scrollIntoView({ block: 'start' }); return s.scrollTop; }
    s.scrollTop += 300;
    await new Promise(r => setTimeout(r, 500));
  }
  return 'notfound';
}
```

スクリーンショットを撮る前に、ウィンドウの幅を `browser_resize` で広げておくと、本文が折り返しにくくなる。
