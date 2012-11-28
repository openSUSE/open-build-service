HoptoadNotifier.configure do |config|
  # Change this to some sensible data for your errbit instance
  config.api_key = CONFIG['errbit_api_key'] || 'YOUR_ERRBIT_API_KEY'
  config.host    = CONFIG['errbit_host'] || 'YOUR_ERRBIT_HOST'
  if CONFIG['errbit_api_key'].blank? || CONFIG['errbit_host'].blank?
    config.development_environments = "production development test"
  else
    config.development_environments = "development test"
  end

  config.ignore_only = %w{ 
  ActiveRecord::RecordNotFound
  ActionController::InvalidAuthenticityToken
  CGI::Session::CookieStore::TamperedWithCookie
  ActionController::UnknownAction
  AbstractController::ActionNotFound
  Timeout::Error
  Net::HTTPBadResponse
  }
 
  config.ignore_by_filter do |exception_data|
    ret=false
    if exception_data[:class] == "ActionController::RoutingError" 
      message = exception_data[:message]
      ret=true if message.includes("[GET]")
      ret=true if message.includes("Required Parameter")
      ret=true if message.includes("Expected AJAX call") 
    end
    ret
  end

end
