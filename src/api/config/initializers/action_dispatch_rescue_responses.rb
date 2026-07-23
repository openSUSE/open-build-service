# Configures which HTTP status uncaught exceptions are assigned
# https://guides.rubyonrails.org/configuring.html#config-action-dispatch-rescue-responses
Rails.application.configure do
  config.action_dispatch.rescue_responses['Backend::Error'] = 500
  config.action_dispatch.rescue_responses['Timeout::Error'] = 408
  config.action_dispatch.rescue_responses['ActionController::InvalidAuthenticityToken'] = 403
end

