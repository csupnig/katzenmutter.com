// Canonical URL for every page ("/index.html" → "/").
export default {
  canonical: (data) => new URL((data.page.url || "/").replace(/index\.html$/, ""), data.site.url).href,
};
