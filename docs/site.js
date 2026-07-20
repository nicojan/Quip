// Quip landing page — progressive enhancement only. The page is fully readable
// with JavaScript off; this adds the sticky-header line, scroll reveals, and
// lazy video playback so five clips never load or play at once.
(function () {
  "use strict";

  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // Sticky header hairline once the page scrolls.
  var header = document.getElementById("top");
  function onScroll() {
    if (window.scrollY > 8) header.classList.add("scrolled");
    else header.classList.remove("scrolled");
  }
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  // Reveal blocks as they enter the viewport.
  var reveals = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window && !reduceMotion) {
    var revObs = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) {
          e.target.classList.add("in");
          revObs.unobserve(e.target);
        }
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.08 });
    reveals.forEach(function (el) { revObs.observe(el); });
  } else {
    reveals.forEach(function (el) { el.classList.add("in"); });
  }

  // Lazy-load and play the feature clips only while they're on screen.
  var lazyVideos = document.querySelectorAll("video source[data-src]");
  if ("IntersectionObserver" in window) {
    var vidObs = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        var video = e.target;
        var source = video.querySelector("source[data-src]");
        if (e.isIntersecting) {
          if (source && !source.getAttribute("src")) {
            source.setAttribute("src", source.getAttribute("data-src"));
            video.load();
          }
          if (!reduceMotion) {
            var p = video.play();
            if (p && p.catch) p.catch(function () {});
          }
        } else if (!video.paused) {
          video.pause();
        }
      });
    }, { threshold: 0.35 });

    lazyVideos.forEach(function (source) { vidObs.observe(source.parentElement); });
  } else {
    // No observer: just wire up the sources so the clips still work.
    lazyVideos.forEach(function (source) {
      source.setAttribute("src", source.getAttribute("data-src"));
      source.parentElement.load();
    });
  }
})();
