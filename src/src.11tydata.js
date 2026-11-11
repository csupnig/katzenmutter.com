// Keep the historic URL scheme (/ernaehrung.html, /tests/katzenfuttertest.html) – these URLs are indexed.
export default {
  permalink: (data) => (data.permalink !== undefined && typeof data.permalink === "string" ? data.permalink : `${data.page.filePathStem}.html`),
};
