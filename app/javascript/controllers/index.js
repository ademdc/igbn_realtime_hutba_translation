// Load all the controllers
import SpeakerController from "./speaker_controller"

let speakerController = null

function initializeControllers() {
  // Clean up existing controller if it exists
  if (speakerController) {
    speakerController = null
  }

  // Initialize speaker controller if on the speaker page
  if (document.getElementById('startRecording')) {
    speakerController = new SpeakerController()
  }
}

// Initialize on Turbo page loads (handles both initial load and navigation)
document.addEventListener('turbo:load', initializeControllers)

// Also handle initial load if Turbo hasn't loaded yet
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeControllers)
} else {
  initializeControllers()
}
