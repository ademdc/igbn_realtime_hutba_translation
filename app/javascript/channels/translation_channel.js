import consumer from "./consumer"

// Only subscribe if we're on the German listener page
if (document.getElementById('translationFeed')) {
  consumer.subscriptions.create("TranslationChannel", {
    connected() {
      console.log("Connected to TranslationChannel")
      this.updateStatus("Connected", true)
    },

    disconnected() {
      console.log("Disconnected from TranslationChannel")
      this.updateStatus("Disconnected", false)
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

      // Create translation item
      const item = document.createElement('div')
      item.className = 'translation-item'

      const timestamp = new Date(data.timestamp).toLocaleTimeString()

      item.innerHTML = `
        <div class="translation-text">${this.escapeHtml(data.text)}</div>
        <div class="translation-time">${timestamp}</div>
      `

      feed.appendChild(item)

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
