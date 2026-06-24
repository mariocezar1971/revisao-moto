// =====================================================================
// REVISAO-MOTO :: Service Worker
// Estrategia: cache-first para app shell, network-first para Supabase
// =====================================================================

const CACHE_VERSION = 'v0.1.0';
const CACHE_NAME = `revisao-moto-${CACHE_VERSION}`;

// App shell - arquivos essenciais para funcionar offline
const APP_SHELL = [
  './',
  './index.html',
  './manifest.json',
  './css/styles.css',
  './src/supabase-client.js',
  './src/auth.js',
  './assets/icon-192.png',
  './assets/icon-512.png',
  // CDNs essenciais
  'https://cdn.tailwindcss.com',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2'
];

// =====================================================================
// INSTALACAO - pre-cache do app shell
// =====================================================================
self.addEventListener('install', (event) => {
  console.log('[SW] Instalando versao', CACHE_VERSION);
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[SW] Pre-cache do app shell');
        return cache.addAll(APP_SHELL).catch((err) => {
          // Nao bloqueia instalacao se algum CDN falhar
          console.warn('[SW] Pre-cache parcial:', err);
        });
      })
      .then(() => self.skipWaiting())
  );
});

// =====================================================================
// ATIVACAO - limpa caches antigos
// =====================================================================
self.addEventListener('activate', (event) => {
  console.log('[SW] Ativando versao', CACHE_VERSION);
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys.filter((key) => key.startsWith('revisao-moto-') && key !== CACHE_NAME)
            .map((key) => {
              console.log('[SW] Removendo cache antigo:', key);
              return caches.delete(key);
            })
      ))
      .then(() => self.clients.claim())
  );
});

// =====================================================================
// FETCH - estrategias por tipo de requisicao
// =====================================================================
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Ignorar metodos diferentes de GET
  if (event.request.method !== 'GET') return;

  // Estrategia para Supabase (network-first - sempre dado fresco)
  if (url.hostname.includes('supabase.co')) {
    event.respondWith(
      fetch(event.request)
        .catch(() => caches.match(event.request))
    );
    return;
  }

  // Estrategia para app shell (cache-first)
  event.respondWith(
    caches.match(event.request)
      .then((cached) => {
        if (cached) return cached;
        return fetch(event.request)
          .then((response) => {
            // Cache somente respostas validas e do mesmo origin/cdn confiavel
            if (response.status === 200 && (url.origin === self.location.origin || APP_SHELL.includes(event.request.url))) {
              const responseClone = response.clone();
              caches.open(CACHE_NAME).then((cache) => cache.put(event.request, responseClone));
            }
            return response;
          })
          .catch(() => {
            // Fallback offline para navegacao
            if (event.request.mode === 'navigate') {
              return caches.match('./index.html');
            }
          });
      })
  );
});

// =====================================================================
// MENSAGEM - controle externo (ex: forcar atualizacao)
// =====================================================================
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
