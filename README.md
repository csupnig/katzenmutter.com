# katzenmutter.com

Static, German-language advice site about cats (food, nutrition, kidney diet, training, balcony safety), monetised with Amazon PartnerNet links. It's an SEO/affiliate experiment.

## Stack

- [Eleventy 3](https://www.11ty.dev/) with Nunjucks templates, plain CSS and about 15 lines of JS. No framework, no cookies, no tracking.
- Hosting: S3 bucket `katzenmutter.com` → CloudFront `E1TPQL9QC7XI6Z` (AWS account `supnig`).
- Deploy: GitHub Actions (`.github/workflows/deploy.yml`) on every push to `master`, authenticated via OIDC (no stored AWS keys).

```bash
npm install
npm start        # dev server with live reload on http://localhost:8080
npm run build    # → _site/
npm run check    # link/affiliate/SEO sanity checks on _site/
```

## Content

| What | Where |
|---|---|
| Pages | `src/*.html`: HTML plus front matter (`title`, `description`, `updated`, `related`, `vetNote`, `affiliate`) |
| Layout, nav, footer, disclosure | `src/_includes/base.njk`, `src/_data/site.json` |
| **Products (ASINs, facts)** | **`src/_data/products.json`**: one list per page; cards/tables render from it |
| Product card & comparison table | `src/_includes/products.njk` |

URLs intentionally keep the historic `.html` scheme because those URLs are indexed.

### Affiliate links

- Cards: add an entry to `products.json`.
- Inline: `{% amazon "B0009587YM", "Linktext" %}` or `{% amazonSearch "suchbegriff", "Linktext" %}`.
- Links are plain `https://www.amazon.de/dp/ASIN?tag=…` with `rel="sponsored nofollow"` and a `*` marker. Each page shows a "Werbung" label, and the footer carries the mandatory Amazon disclosure.
- Optional per-page tracking ID: set `amazonTag: katzenmutter-niere-21` in a page's front matter (create the ID in PartnerNet first). This makes earnings attributable per page.
- **Never** show prices or Amazon star ratings (not allowed without API access), and don't call anything a "Test"/"Testsieger" unless it was actually tested.

### Videos

`{% youtube "ID", "Titel" %}` renders a click-to-load placeholder (youtube-nocookie), so no consent banner is needed.

## One-time AWS setup

`infra/setup.sh` (run with `AWS_PROFILE=supnig`) creates the GitHub OIDC deploy role and publishes `infra/redirects.js` as a CloudFront Function (www → apex, legacy URLs). It also adds the `www` alias, the 404 page and TLS 1.2 to the distribution, and points `www` DNS at CloudFront.
