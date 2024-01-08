Rails.application.config.middleware.use OmniAuth::Builder do
  unless Rails.env.production?
    provider :developer,
             :fields => [:username, :password],
             :uid_field => :username
  end
end
