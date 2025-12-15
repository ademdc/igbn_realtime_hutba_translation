import consumer from "./consumer"

// Only subscribe if we're on a listener page
const translationFeed = document.getElementById('translationFeed')
if (translationFeed) {
  const language = translationFeed.dataset.language || 'german'

  consumer.subscriptions.create(
    { channel: "TranslationChannel", language: language },
    {
      connected() {
        console.log(`Connected to TranslationChannel for ${language}`)
        this.updateStatus("Verbunden", true)
      },

    disconnected() {
      console.log(`Disconnected from TranslationChannel for ${language}`)
      this.updateStatus("Getrennt", false)
    },

    received(data) {
      console.log("Received translation:", data)
      this.displayTranslation(data)
    },

    updateStatus(status, connected) {
      const statusText = document.getElementById('connectionStatus')
      const statusDot = document.getElementById('statusDot')

      if (statusText) {
        statusText.textContent = status
      }

      if (statusDot) {
        statusDot.className = connected ? 'dot connected' : 'dot'
      }
    },

    displayTranslation(data) {
      const feed = document.getElementById('translationFeed')
      const noTranslations = feed.querySelector('.no-translations')

      // Remove "waiting" message on first translation
      if (noTranslations) {
        noTranslations.remove()
      }

      // Get or create continuous text container
      let textContainer = feed.querySelector('.continuous-text')
      if (!textContainer) {
        textContainer = document.createElement('div')
        textContainer.className = 'continuous-text'
        feed.appendChild(textContainer)
      }

      // Create a span for new text with highlight animation
      const span = document.createElement('span')
      span.className = 'new-text'
      span.textContent = data.text

      // Add space before if not first text
      if (textContainer.children.length > 0) {
        textContainer.appendChild(document.createTextNode(' '))
      }

      textContainer.appendChild(span)

      // Remove animation class after animation completes
      setTimeout(() => {
        span.className = ''
      }, 3000)

      // Auto-scroll to bottom
      feed.scrollTop = feed.scrollHeight
    },

    escapeHtml(text) {
      const div = document.createElement('div')
      div.textContent = text
      return div.innerHTML
    }
  })
}
