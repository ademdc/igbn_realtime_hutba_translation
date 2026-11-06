(() => {
  // app/javascript/marketing.js
  var WORD_DELAY_MS = 170;
  var SENTENCE_PAUSE_MS = 2600;
  var HIGHLIGHT_MS = 900;
  var RTL_LANGUAGES = ["ar", "ur"];
  function startDemo(root) {
    const script = JSON.parse(root.querySelector("[data-demo-script]").textContent);
    const originalEl = root.querySelector("[data-demo-original]");
    const translationEl = root.querySelector("[data-demo-translation]");
    const languageButtons = root.querySelectorAll("[data-demo-language]");
    const sourceLabelEl = root.querySelector("[data-demo-source-label]");
    const sources = JSON.parse(root.dataset.sources);
    const sourceLabels = JSON.parse(root.dataset.sourceLabels);
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    let language = root.dataset.language;
    let sentenceIndex = 0;
    let sourceIndex = 0;
    let timer = null;
    function selectLanguage(code) {
      language = code;
      languageButtons.forEach((button) => {
        button.setAttribute("aria-pressed", String(button.dataset.demoLanguage === code));
      });
      translationEl.lang = code;
      if (sources[sourceIndex] === code)
        sourceIndex = (sourceIndex + 1) % sources.length;
      playSentence();
    }
    function playSentence() {
      clearTimeout(timer);
      const sentence = script[sentenceIndex];
      const source = sources[sourceIndex];
      originalEl.textContent = sentence[source];
      originalEl.lang = source;
      originalEl.dir = RTL_LANGUAGES.includes(source) ? "rtl" : "ltr";
      sourceLabelEl.textContent = sourceLabels[source];
      if (reducedMotion) {
        translationEl.textContent = sentence[language];
        timer = setTimeout(nextSentence, SENTENCE_PAUSE_MS * 2);
        return;
      }
      const words = sentence[language].split(" ");
      translationEl.textContent = "";
      const caret = document.createElement("span");
      caret.className = "caret";
      caret.setAttribute("aria-hidden", "true");
      translationEl.append(caret);
      let i = 0;
      const addWord = () => {
        const word = document.createElement("span");
        word.className = "word word--new";
        word.textContent = words[i];
        caret.before(word, " ");
        setTimeout(() => word.classList.remove("word--new"), HIGHLIGHT_MS);
        i += 1;
        if (i < words.length) {
          timer = setTimeout(addWord, WORD_DELAY_MS);
        } else {
          caret.remove();
          timer = setTimeout(nextSentence, SENTENCE_PAUSE_MS);
        }
      };
      timer = setTimeout(addWord, WORD_DELAY_MS * 3);
    }
    function nextSentence() {
      sentenceIndex = (sentenceIndex + 1) % script.length;
      do {
        sourceIndex = (sourceIndex + 1) % sources.length;
      } while (sources[sourceIndex] === language);
      playSentence();
    }
    languageButtons.forEach((button) => {
      button.addEventListener("click", () => selectLanguage(button.dataset.demoLanguage));
    });
    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) {
        playSentence();
      } else {
        clearTimeout(timer);
      }
    });
    observer.observe(root);
  }
  document.querySelectorAll("[data-demo]").forEach(startDemo);
  function slugify(value) {
    return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/đ/gi, "dj").replace(/ß/g, "ss").replace(/ı/g, "i").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 40).replace(/-+$/, "");
  }
  function startSignup(form) {
    const nameInput = form.querySelector("[data-signup-name]");
    const subdomainInput = form.querySelector("[data-signup-subdomain]");
    const status = form.querySelector("[data-signup-status]");
    const defaultHint = status.textContent;
    let edited = subdomainInput.value !== "";
    let timer = null;
    let request = 0;
    const check = () => {
      clearTimeout(timer);
      const value = subdomainInput.value.trim();
      if (value.length < 3) {
        status.textContent = defaultHint;
        delete status.dataset.state;
        return;
      }
      timer = setTimeout(async () => {
        const current = ++request;
        try {
          const response = await fetch(`${subdomainInput.dataset.checkUrl}?subdomain=${encodeURIComponent(value)}`);
          const result = await response.json();
          if (current !== request)
            return;
          status.textContent = result.available ? `\u2713 ${result.host}` : result.message;
          status.dataset.state = result.available ? "ok" : "error";
        } catch {
          status.textContent = defaultHint;
          delete status.dataset.state;
        }
      }, 300);
    };
    nameInput.addEventListener("input", () => {
      if (edited)
        return;
      subdomainInput.value = slugify(nameInput.value);
      check();
    });
    subdomainInput.addEventListener("input", () => {
      edited = subdomainInput.value !== "";
      subdomainInput.value = subdomainInput.value.toLowerCase().replace(/[^a-z0-9-]/g, "");
      check();
    });
    if (subdomainInput.value)
      check();
  }
  document.querySelectorAll("[data-signup]").forEach(startSignup);
})();
//# sourceMappingURL=/assets/marketing.js.map
