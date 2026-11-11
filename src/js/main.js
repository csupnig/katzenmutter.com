// Click-to-load YouTube: no request to YouTube before the visitor opts in.
document.addEventListener("click", (e) => {
  const btn = e.target.closest(".video-load");
  if (!btn) return;
  const fig = btn.closest("[data-yt]");
  const iframe = document.createElement("iframe");
  iframe.src = `https://www.youtube-nocookie.com/embed/${encodeURIComponent(fig.dataset.yt)}?autoplay=1`;
  iframe.title = btn.querySelector(".video-title")?.textContent || "YouTube-Video";
  iframe.allow = "accelerometer; autoplay; encrypted-media; picture-in-picture";
  iframe.allowFullscreen = true;
  iframe.loading = "lazy";
  fig.replaceChildren(iframe);
});
