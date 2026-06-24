# frozen_string_literal: true

ReActionView.configure do |config|
  # Intercept .html.erb templates and process them with `Herb::Engine` for enhanced features
  config.intercept_erb = true

  config.debug_mode = false

  # Validation mode (:raise, :overlay, or :none) — defaults to :raise in test, :overlay otherwise
  config.validation_mode = :overlay
end
