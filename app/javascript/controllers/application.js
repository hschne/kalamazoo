import { Application } from '@hotwired/stimulus'
import { registerControllers } from 'stimulus-vite-helpers'

const application = Application.start()
const controllers = import.meta.glob('./**/*_controller.{js,ts}', {
  eager: true,
})
registerControllers(application, controllers)

application.debug = false
window.Stimulus = application
export { application }
