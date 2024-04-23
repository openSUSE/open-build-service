Rails.application.config.middleware.use OmniAuth::Builder do
  unless Rails.env.production?
    provider :github,
             ENV.fetch('GITHUB_KEY', nil),
             ENV.fetch('GITHUB_SECRET', nil),
             { provider_ignores_state: true }
  end
end
