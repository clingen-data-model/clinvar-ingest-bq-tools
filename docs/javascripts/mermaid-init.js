document$.subscribe(function () {
  // fence_code_format wraps content in <pre class="mermaid"><code>...</code></pre>
  // but mermaid.js expects raw text inside <pre class="mermaid">, not a <code> child.
  // Unwrap the <code> tags before initializing mermaid.
  document.querySelectorAll("pre.mermaid code").forEach(function (codeEl) {
    var pre = codeEl.parentElement;
    pre.textContent = codeEl.textContent;
  });
  mermaid.initialize({ startOnLoad: true });
  mermaid.run();
});
