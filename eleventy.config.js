// katzenmutter.com – Eleventy build
// Pages live in src/ as .html (Nunjucks) with front matter; output goes to _site/.

const escapeHtml = (s = "") =>
  String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

export default function (eleventyConfig) {
  eleventyConfig.addPassthroughCopy({ "src/assets": "assets" });
  eleventyConfig.addPassthroughCopy("src/css");
  eleventyConfig.addPassthroughCopy("src/js");
  eleventyConfig.addPassthroughCopy("src/robots.txt");
  eleventyConfig.addPassthroughCopy("src/google90d75c7d5b5df82c.html");
  eleventyConfig.ignores.add("src/google90d75c7d5b5df82c.html");

  /** Plain amazon.de product URL with tracking ID (page front matter `amazonTag` overrides the site default). */
  function amazonUrl(asin, ctx) {
    const site = ctx?.site ?? {};
    const tag = ctx?.amazonTag || site.amazonTag;
    return `https://www.amazon.de/dp/${encodeURIComponent(asin)}?tag=${encodeURIComponent(tag)}`;
  }

  /** Amazon search URL (for "mehr Auswahl" links). */
  function amazonSearchUrl(query, ctx) {
    const site = ctx?.site ?? {};
    const tag = ctx?.amazonTag || site.amazonTag;
    return `https://www.amazon.de/s?k=${encodeURIComponent(query)}&tag=${encodeURIComponent(tag)}`;
  }

  eleventyConfig.addShortcode("amazonUrl", function (asin) {
    return amazonUrl(asin, this.ctx);
  });

  // {% amazon "B0009587YM", "Link text" %} – inline affiliate link, marked with * (see footer note)
  eleventyConfig.addShortcode("amazon", function (asin, text) {
    return `<a class="aff" href="${amazonUrl(asin, this.ctx)}" rel="sponsored nofollow noopener" target="_blank">${escapeHtml(text)}</a><sup class="aff-mark" title="Werbelink">*</sup>`;
  });

  // {% amazonSearch "phosphorarmes Katzenfutter", "Link text" %}
  eleventyConfig.addShortcode("amazonSearch", function (query, text) {
    return `<a class="aff" href="${amazonSearchUrl(query, this.ctx)}" rel="sponsored nofollow noopener" target="_blank">${escapeHtml(text)}</a><sup class="aff-mark" title="Werbelink">*</sup>`;
  });

  // {% youtube "id", "Titel" %} – no request to YouTube until the visitor clicks (no consent banner needed)
  eleventyConfig.addShortcode("youtube", function (id, title) {
    const t = escapeHtml(title);
    return `<figure class="video" data-yt="${escapeHtml(id)}">
  <button type="button" class="video-load" aria-label="Video „${t}“ laden">
    <span class="video-play" aria-hidden="true">▶</span>
    <span class="video-title">${t}</span>
  </button>
  <figcaption class="video-note">Erst beim Klick wird eine Verbindung zu YouTube (Google) hergestellt. <a href="/impressum.html#datenschutz">Datenschutz</a></figcaption>
</figure>`;
  });

  // Filter form for use inside macros: {{ p.asin | amazonLink(amazonTag or site.amazonTag) }}
  eleventyConfig.addFilter("amazonLink", (asin, tag) => amazonUrl(asin, { amazonTag: tag }));

  eleventyConfig.addFilter("isoDate", (d) => new Date(d).toISOString().slice(0, 10));
  eleventyConfig.addFilter("deDate", (d) =>
    new Date(d).toLocaleDateString("de-DE", { day: "numeric", month: "long", year: "numeric" })
  );
  eleventyConfig.addFilter("byKey", (arr, key) => (arr || []).find((p) => p.key === key));

  return {
    dir: { input: "src", includes: "_includes", data: "_data", output: "_site" },
    htmlTemplateEngine: "njk",
    markdownTemplateEngine: "njk",
  };
}
