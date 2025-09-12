// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "src/turbo_error"

import { Application } from "@hotwired/stimulus"
import { MarksmithController, ListContinuationController } from "@avo-hq/marksmith"

// Start Stimulus application
const application = Application.start()
application.register("marksmith", MarksmithController)
application.register("list-continuation", ListContinuationController)

Turbo.session.drive = false
