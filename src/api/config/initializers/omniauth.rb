Rails.application.config.middleware.use OmniAuth::Builder do
  unless Rails.env.production?
    provider :github,
             ENV.fetch('CLIENT_ID', nil),
             ENV.fetch('CLIENT_SECRET', nil),
             { provider_ignores_state: true }
  end
end
