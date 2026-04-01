const CACHE_NAME = "traneem-pwa-v2";
const PRECACHE_URLS = [
  "/",
  "/index.html",
  "/manifest.webmanifest",
  "/sw.js",
  "/main.js",
  "/main.css",
  "/default-cover.jpg",
  "/cairo.css",
  "/favicon-48.png",
  "/icon-192.png",
  "/icon-512.png",
  "/icon-maskable-512.png",
  "/cairo-1.ttf",
  "/cairo-2.ttf",
  "/cairo-3.ttf",
  "/cairo-4.ttf",
  "/cairo-5.ttf"
];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(PRECACHE_URLS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  if (req.mode === 'navigate') {
    event.respondWith(fetch(req).then((res) => {
      const copy = res.clone();
      caches.open(CACHE_NAME).then((cache) => cache.put('/index.html', copy));
      return res;
    }).catch(() => caches.match('/index.html')));
    return;
  }

  event.respondWith(caches.match(req).then((cached) => {
    if (cached) return cached;
    return fetch(req).then((res) => {
      const copy = res.clone();
      caches.open(CACHE_NAME).then((cache) => cache.put(req, copy));
      return res;
    }).catch(() => {
      if (req.destination === 'image') return caches.match('/assets/default-cover.jpg');
      return new Response('', { status: 504, statusText: 'Offline' });
    });
  }));
});
