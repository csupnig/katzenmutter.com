// Post-build sanity checks on _site/ (run: npm run check)
//  - every internal link/asset resolves to a built file
//  - every Amazon link is a plain amazon.de link with our tag and rel="sponsored"
//  - no legacy redirector links or tracking scripts remain
//  - every page has a title, description and canonical
import { readFileSync, readdirSync, existsSync, statSync } from "node:fs";
import { join, dirname, resolve } from "node:path";

const root = resolve("_site");
const site = JSON.parse(readFileSync("src/_data/site.json", "utf8"));
const errors = [];

const walk = (d) => readdirSync(d).flatMap((f) => (statSync(join(d, f)).isDirectory() ? walk(join(d, f)) : [join(d, f)]));
const pages = walk(root).filter((f) => f.endsWith(".html") && !f.includes("google"));

for (const file of pages) {
  const rel = file.slice(root.length);
  const html = readFileSync(file, "utf8");
  for (const [tag] of html.matchAll(/<(?:a|link|script|img)\b[^>]*>/g)) {
    const url = (tag.match(/\s(?:href|src)="([^"]+)"/) || [])[1];
    if (!url || url.startsWith("#") || url.startsWith("mailto:")) continue;
    if (/^https?:\/\//.test(url)) {
      if (/amazon-global\.io|amazon-adsystem|google-analytics|hotjar/.test(url)) errors.push(`${rel}: legacy/tracking URL ${url}`);
      if (/amazon\.de/.test(url)) {
        if (!url.startsWith("https://www.amazon.de/")) errors.push(`${rel}: non-canonical Amazon URL ${url}`);
        if (!/[?&]tag=[\w-]+-21\b/.test(url)) errors.push(`${rel}: Amazon link without tag ${url}`);
        if (!/rel="[^"]*sponsored/.test(tag)) errors.push(`${rel}: Amazon link without rel=sponsored ${url}`);
        if (/\/dp\/(undefined|null|)\?/.test(url)) errors.push(`${rel}: Amazon link without ASIN ${url}`);
      }
      continue;
    }
    if (url.startsWith("//")) { errors.push(`${rel}: protocol-relative URL ${url}`); continue; }
    const path = url.split(/[?#]/)[0];
    const target = path.startsWith("/") ? join(root, path) : join(dirname(file), path);
    const ok = existsSync(target) && (statSync(target).isFile() || existsSync(join(target, "index.html")));
    if (!ok) errors.push(`${rel}: broken internal link ${url}`);
  }
  for (const [name, re] of [["title", /<title>[^<]{10,}<\/title>/], ["description", /<meta name="description" content="[^"]{50,}"/], ["canonical", /<link rel="canonical" href="https:\/\/katzenmutter\.com\//]]) {
    if (!re.test(html)) errors.push(`${rel}: missing/short ${name}`);
  }
  if (/\*<\/a>|aff-mark/.test(html) && !html.includes("Als Amazon-Partner verdiene ich an qualifizierten Verkäufen")) errors.push(`${rel}: affiliate links without Amazon disclosure`);
}

if (!existsSync(join(root, "sitemap.xml"))) errors.push("sitemap.xml missing");

if (errors.length) {
  console.error(errors.map((e) => "✗ " + e).join("\n"));
  console.error(`\n${errors.length} problem(s) in ${pages.length} pages`);
  process.exit(1);
}
console.log(`✓ ${pages.length} pages OK (tag ${site.amazonTag})`);
