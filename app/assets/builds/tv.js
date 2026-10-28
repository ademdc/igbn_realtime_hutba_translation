(() => {
  // app/javascript/tv.js
  var button = document.querySelector("[data-fullscreen]");
  if (button && document.fullscreenEnabled) {
    button.hidden = false;
    button.addEventListener("click", () => document.documentElement.requestFullscreen());
    document.addEventListener("fullscreenchange", () => {
      button.hidden = Boolean(document.fullscreenElement);
    });
  }
})();
//# sourceMappingURL=/assets/tv.js.map
