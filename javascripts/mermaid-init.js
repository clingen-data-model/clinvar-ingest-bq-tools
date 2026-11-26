// Load mermaid dynamically, then unwrap <code> tags and render diagrams.
// fence_code_format produces <pre class="mermaid"><code>...</code></pre>
// but mermaid expects raw text in <pre class="mermaid"> (no <code> child).
(function () {
  var script = document.createElement("script");
  script.src = "https://unpkg.com/mermaid@11/dist/mermaid.min.js";
  script.onload = function () {
    mermaid.initialize({ startOnLoad: false });
    document.querySelectorAll("pre.mermaid code").forEach(function (codeEl) {
      var pre = codeEl.parentElement;
      pre.textContent = codeEl.textContent;
    });
    mermaid.run({ querySelector: "pre.mermaid" });
  };
  document.head.appendChild(script);
})();
