# P2-06 Product photos
Goal: optional photo per product without touching the database size or free-tier egress.
- Migration: private Storage bucket `product-photos`, path `<tenant_id>/<product_id>.jpg`, policies so a user reads and writes only their tenant prefix (pgTAP test for it). Size limit 200 KB.
- Client: capture or pick, resize to about 640 px JPEG under 100 KB, store locally first, upload queue when online, then `upsert_product` sets `photo_path`.
- Show cached thumbnails (disk cache); never download full lists of images at once.
- Done when: pgTAP policy test passes, a photo added offline uploads after reconnect, `flutter test` green. Use Sonnet (policy test reviewed with care).
