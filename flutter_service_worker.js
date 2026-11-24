'use strict';

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      try {
        if ('caches' in self) {
          const keys = await caches.keys();
          await Promise.all(keys.map((k) => caches.delete(k)));
        }
      } catch (e) {
        console.warn('Failed to clear caches:', e);
      }
      try {
        await self.registration.unregister();
      } catch (e) {
        console.warn('Failed to unregister service worker:', e);
      }
    })()
  );
});
