// Load all the controllers
import SpeakerController from "./speaker_controller"

let speakerController = null

function initializeControllers() {
  // Both the initial load and turbo:load call this. Set up each speaker panel only once:
  // a second controller would start a second recorder and send every audio chunk twice.
  const panel = document.getElementById('speakerPanel')
  if (!panel || panel.dataset.initialized) return

  panel.dataset.initialized = "true"
  speakerController = new SpeakerController()
}

// Initialize on Turbo page loads (handles both initial load and navigation)
document.addEventListener('turbo:load', initializeControllers)

// Also handle initial load if Turbo hasn't loaded yet
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeControllers)
} else {
  initializeControllers()
}
