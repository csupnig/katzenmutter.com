// CloudFront Function (viewer-request) for katzenmutter.com
// - www.katzenmutter.com → katzenmutter.com (301)
// - removed legacy pages → closest current page (301)
var LEGACY = {
  "/tests/ndrtest.html": "/tests/katzenfuttertest.html",
  "/tests/testberichte.html": "/tests/katzenfuttertest.html",
  "/tests/": "/tests/katzenfuttertest.html",
  "/index.html": "/"
};

function redirect(location) {
  return { statusCode: 301, statusDescription: "Moved Permanently", headers: { location: { value: location } } };
}

function handler(event) {
  var req = event.request;
  var host = req.headers.host ? req.headers.host.value : "";
  if (host.indexOf("www.") === 0) {
    var qs = Object.keys(req.querystring).length ? "?" + Object.keys(req.querystring).map(function (k) { return k + "=" + req.querystring[k].value; }).join("&") : "";
    return redirect("https://katzenmutter.com" + (LEGACY[req.uri] || req.uri) + qs);
  }
  if (LEGACY[req.uri]) return redirect(LEGACY[req.uri]);
  if (req.uri.endsWith("/")) req.uri += "index.html";
  return req;
}
