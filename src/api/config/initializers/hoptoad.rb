HoptoadNotifier.configure do |config|
  # Change this to some sensible data for your errbit instance
  config.api_key = CONFIG['errbit_api_key'] || 'YOUR_ERRBIT_API_KEY'
  config.host    = Configuration.errbit_url || 'YOUR_ERRBIT_HOST'
  if CONFIG['errbit_api_key'].blank? || Configuration.errbit_url.blank?
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
    if exception_data[:error_class] == "ActionController::RoutingError" 
      message = exception_data[:error_message]
      ret=true if message =~ %r{Required Parameter}
      ret=true if message =~ %r{\[GET\]}
      ret=true if message =~ %r{Expected AJAX call}
    end
    ret
  end

end
