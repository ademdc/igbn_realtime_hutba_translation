(() => {
  // app/javascript/marketing.js
  var WORD_DELAY_MS = 170;
  var SENTENCE_PAUSE_MS = 2600;
  var HIGHLIGHT_MS = 900;
  function startDemo(root) {
    const script = JSON.parse(root.querySelector("[data-demo-script]").textContent);
    const originalEl = root.querySelector("[data-demo-original]");
    const translationEl = root.querySelector("[data-demo-translation]");
    const languageButtons = root.querySelectorAll("[data-demo-language]");
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    let language = root.dataset.language;
    let sentenceIndex = 0;
    let timer = null;
    function selectLanguage(code) {
      language = code;
      languageButtons.forEach((button) => {
        button.setAttribute("aria-pressed", String(button.dataset.demoLanguage === code));
      });
      translationEl.lang = code;
      playSentence();
    }
    function playSentence() {
      clearTimeout(timer);
      const sentence = script[sentenceIndex];
      originalEl.textContent = sentence.bs;
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
})();
//# sourceMappingURL=/assets/marketing.js.map
