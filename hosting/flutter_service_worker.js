// 옛 주소(GitHub Pages)에 설치돼 있던 앱의 서비스 워커를 정리하는 종료용 워커.
// 브라우저가 업데이트를 확인하면 이 파일로 바뀌고, 캐시를 지우고 스스로 해제한 뒤
// 열려 있는 페이지를 새로고침해 새 주소 안내 페이지로 보낸다.
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (event) {
  event.waitUntil((async function () {
    try {
      const keys = await caches.keys();
      await Promise.all(keys.map(function (k) { return caches.delete(k); }));
    } catch (e) {}
    await self.registration.unregister();
    const list = await self.clients.matchAll({ type: 'window' });
    list.forEach(function (c) { c.navigate(c.url); });
  })());
});
