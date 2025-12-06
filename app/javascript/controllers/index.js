// Load all the controllers
import SpeakerController from "./speaker_controller"

// Register controllers
if (document.getElementById('startRecording')) {
  new SpeakerController()
}
