import consumer from "./consumer"

// Listener pages show one feed; the TV screen can show one feed per language.
const MAX_SPANS = 400

const statusText = document.getElementById('connectionStatus')
const statusDot = document.getElementById('statusDot')
const feeds = document.querySelectorAll('[data-translation-feed]')

let wakeLock = null

async function requestWakeLock() {
  if (!('wakeLock' in navigator) || wakeLock) return

  try {
    wakeLock = await navigator.wakeLock.request('screen')
    wakeLock.addEventListener('release', () => { wakeLock = null })
  } catch (err) {
    console.log('Could not activate wake lock:', err.message)
  }
}

function updateStatus(text, connected) {
  if (statusText && text) statusText.textContent = text
  if (statusDot) statusDot.dataset.connected = connected
}

function displayTranslation(feed, text) {
  feed.querySelector('.no-translations')?.remove()

  let container = feed.querySelector('.continuous-text')
  if (!container) {
    container = document.createElement('div')
    container.className = 'continuous-text'
    feed.appendChild(container)
  }

  if (container.children.length > 0) {
    container.appendChild(document.createTextNode(' '))
  }

  const span = document.createElement('span')
  span.className = 'new-text'
  span.textContent = text
  container.appendChild(span)
  setTimeout(() => { span.className = '' }, 3000)

  // Long khutbahs: drop the oldest text so the page stays light
  while (container.children.length > MAX_SPANS) {
    container.firstElementChild.remove()
  }

  feed.scrollTop = feed.scrollHeight
}

const subscriptions = Array.from(feeds).map((feed) => {
  const language = feed.dataset.language || 'de'

  return consumer.subscriptions.create(
    { channel: "TranslationChannel", language: language },
    {
      connected() {
        updateStatus(feed.dataset.connectedText, true)
        requestWakeLock()
      },

      disconnected() {
        updateStatus(feed.dataset.disconnectedText, false)
      },

      received(data) {
        if (data.text) displayTranslation(feed, data.text)
      }
    }
  )
})

if (subscriptions.length > 0) {
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState !== 'visible') return

    requestWakeLock()
    // Phones suspend sockets in the background; reconnect when the tab comes back
    setTimeout(() => {
      if (!consumer.connection.isActive()) consumer.connection.reopen()
    }, 100)
  })
}
