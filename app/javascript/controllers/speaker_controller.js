import consumer from "../channels/consumer"

export default class SpeakerController {
  constructor() {
    this.startButton = document.getElementById('startRecording')
    this.stopButton = document.getElementById('stopRecording')
    this.statusDiv = document.getElementById('status')
    this.transcriptionDiv = document.getElementById('transcription')
    this.transcriptionBox = document.getElementById('transcriptionBox')

    this.mediaRecorder = null
    this.audioContext = null
    this.channel = null
    this.isRecording = false
    this.wakeLock = null

    this.bindEvents()
  }

  bindEvents() {
    this.startButton.addEventListener('click', () => this.startRecording())
    this.stopButton.addEventListener('click', () => this.stopRecording())
  }

  async startRecording() {
    try {
      // Request screen wake lock to prevent phone from sleeping
      if ('wakeLock' in navigator) {
        try {
          this.wakeLock = await navigator.wakeLock.request('screen')
          console.log('Screen wake lock activated')

          // Handle wake lock release (e.g., when page becomes hidden)
          this.wakeLock.addEventListener('release', () => {
            console.log('Screen wake lock released')
          })
        } catch (err) {
          console.warn('Could not activate wake lock:', err)
        }
      }

      // Request microphone access
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          channelCount: 1,
          sampleRate: 16000,
          echoCancellation: true,
          noiseSuppression: true
        }
      })

      // Create subscription to TranslationChannel
      this.channel = consumer.subscriptions.create("TranslationChannel", {
        connected: () => {
          console.log("Connected to translation channel")
          this.updateStatus("Connected and recording...", "success")
        },
        disconnected: () => {
          console.log("Disconnected from translation channel")
        },
        received: (data) => {
          // Display Bosnian original transcription
          if (data.original) {
            console.log("Received original:", data.original)
            this.transcriptionDiv.textContent = data.original
          }
        }
      })

      // Set up audio context for processing
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)({ sampleRate: 16000 })
      const source = this.audioContext.createMediaStreamSource(stream)

      // Create script processor for real-time audio processing
      const processor = this.audioContext.createScriptProcessor(4096, 1, 1)

      processor.onaudioprocess = (e) => {
        if (this.isRecording && this.channel) {
          const audioData = e.inputBuffer.getChannelData(0)

          // Convert Float32Array to Int16Array for Soniox
          const int16Data = this.float32ToInt16(audioData)

          // Send to server
          this.channel.send({ audio: Array.from(int16Data) })
        }
      }

      source.connect(processor)
      processor.connect(this.audioContext.destination)

      this.isRecording = true
      this.processor = processor

      // Update UI
      this.startButton.style.display = 'none'
      this.stopButton.style.display = 'inline-block'
      this.transcriptionBox.style.display = 'block'
      this.updateStatus("Recording... Speak in Bosnian", "success")

    } catch (error) {
      console.error('Error accessing microphone:', error)
      this.updateStatus(`Error: ${error.message}`, "error")
    }
  }

  stopRecording() {
    this.isRecording = false

    // Release wake lock
    if (this.wakeLock) {
      this.wakeLock.release()
        .then(() => {
          console.log('Screen wake lock released')
          this.wakeLock = null
        })
        .catch(err => {
          console.warn('Error releasing wake lock:', err)
        })
    }

    if (this.audioContext) {
      this.audioContext.close()
      this.audioContext = null
    }

    if (this.processor) {
      this.processor.disconnect()
      this.processor = null
    }

    if (this.channel) {
      this.channel.unsubscribe()
      this.channel = null
    }

    // Update UI
    this.startButton.style.display = 'inline-block'
    this.stopButton.style.display = 'none'
    this.updateStatus("Recording stopped", "info")
  }

  float32ToInt16(float32Array) {
    const int16Array = new Int16Array(float32Array.length)
    for (let i = 0; i < float32Array.length; i++) {
      const s = Math.max(-1, Math.min(1, float32Array[i]))
      int16Array[i] = s < 0 ? s * 0x8000 : s * 0x7FFF
    }
    return int16Array
  }

  updateStatus(message, type) {
    this.statusDiv.textContent = message
    this.statusDiv.className = `status status-${type}`
  }
}
