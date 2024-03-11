Rails.application.config.middleware.use OmniAuth::Builder do
  unless Rails.env.production?
    provider :developer,
             :fields => [:username, :password],
             :uid_field => :username
    provider :github,
             ENV['GITHUB_KEY'],
             ENV['GITHUB_SECRET'],
             {:provider_ignores_state => true}
  end
end
