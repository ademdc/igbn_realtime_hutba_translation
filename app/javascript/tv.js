// TV screen: offer fullscreen once (browsers require a click), then stay out of the way.
const button = document.querySelector('[data-fullscreen]')

if (button && document.fullscreenEnabled) {
  button.hidden = false
  button.addEventListener('click', () => document.documentElement.requestFullscreen())
  document.addEventListener('fullscreenchange', () => {
    button.hidden = Boolean(document.fullscreenElement)
  })
}
