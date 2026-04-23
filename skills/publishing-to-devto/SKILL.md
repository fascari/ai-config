---
name: publishing-to-devto
description: Use when publishing or updating a dev.to article draft from a local article.md file. Handles image hosting via Imgur, cover upload, and draft creation or update via the dev.to API.
---

# Publishing to dev.to

Publishes a local `article.md` bundle to dev.to as a draft. Uploads all images to Imgur for public hosting, sets the cover, and creates or updates the article via the dev.to REST API.

## Prerequisites

- `DEVTO_API_KEY` exported in the shell (add to `~/.zshrc` and `source ~/.zshrc`)
- `jq` installed (`brew install jq`)
- Article at `articles/dev.to/{slug}/article.md` with valid YAML front matter
- Cover image at `articles/dev.to/{slug}/cover.png` (1000x420)
- Diagrams as PNGs at `articles/dev.to/{slug}/imgs/*.png`

## Step 1 — Verify API key

```bash
source ~/.zshrc
curl -s -o /dev/null -w "%{http_code}" -H "api-key: $DEVTO_API_KEY" https://dev.to/api/users/me
# must return 200
```

## Step 2 — Upload cover to Imgur

```bash
COVER_RESP=$(curl -s -X POST https://api.imgur.com/3/image \
  -H "Authorization: Client-ID 546c25a59c58ad7" \
  -F "image=@articles/dev.to/{slug}/cover.png" \
  -F "type=file")
COVER_URL=$(echo "$COVER_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['link'])")
echo "Cover: $COVER_URL"
```

Update `cover_image:` in the article front matter with the returned URL.

## Step 3 — Upload diagrams to Imgur

For each PNG in `articles/dev.to/{slug}/imgs/`:

```bash
IMG_RESP=$(curl -s -X POST https://api.imgur.com/3/image \
  -H "Authorization: Client-ID 546c25a59c58ad7" \
  -F "image=@articles/dev.to/{slug}/imgs/{name}.png" \
  -F "type=file")
IMG_URL=$(echo "$IMG_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['link'])")
echo "{name}.png => $IMG_URL"
```

Replace every `./imgs/{name}.png` reference in `article.md` with the returned Imgur URL.

## Step 4 — Create draft (first publish)

```bash
source ~/.zshrc
PAYLOAD=$(jq -n --rawfile body articles/dev.to/{slug}/article.md '{"article":{"body_markdown":$body}}')
curl -s -X POST https://dev.to/api/articles \
  -H "api-key: $DEVTO_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print('id:', d.get('id'), 'url:', d.get('url'))"
```

Save the returned `id` — you need it for updates.

## Step 5 — Update existing draft

```bash
source ~/.zshrc
ARTICLE_ID="{id from step 4}"
PAYLOAD=$(jq -n --rawfile body articles/dev.to/{slug}/article.md '{"article":{"body_markdown":$body}}')
curl -s -X PUT "https://dev.to/api/articles/$ARTICLE_ID" \
  -H "api-key: $DEVTO_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print('cover:', d.get('cover_image','?')[:60])"
```

## Step 6 — Publish (when ready)

Set `published: true` in the front matter and run Step 5 again. The article goes live immediately.

After publish, fill in all `<!-- TODO -->` link placeholders in both articles with the live URLs.

## Notes

- The `cover_image` field only works via the front matter in `body_markdown`, not as a standalone API field.
- Imgur anonymous upload uses Client-ID `546c25a59c58ad7` (public dev client). For production use, register your own app at https://api.imgur.com/oauth2/addclient.
- dev.to processes the Imgur URL through its own CDN (`media2.dev.to`). This is expected behavior.
- Local `./imgs/` paths are invisible to dev.to readers. Always replace with absolute Imgur URLs before publishing.
- The article slug in the URL is auto-generated from the title at creation time and contains a random suffix. It is updated to a clean slug on first publish.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `403` on POST | Key not in env | `source ~/.zshrc` and verify with `/users/me` |
| `400` on POST | Invalid JSON payload | Use `jq --rawfile` to encode the markdown body |
| `cover_image` returns null | Sent as standalone field | Include `cover_image` in front matter, re-send full `body_markdown` |
| Images not showing | Local `./imgs/` paths | Upload to Imgur and replace paths in `article.md` |
| Draft not found | Wrong article ID | Check ID with `GET /api/articles/me/unpublished` |
