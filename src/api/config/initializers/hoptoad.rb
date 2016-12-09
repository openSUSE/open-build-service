HoptoadNotifier.configure do |config|
  # Change this to some sensible data for your errbit instance
  config.api_key = CONFIG['errbit_api_key'] || 'YOUR_ERRBIT_API_KEY'
  config.host    = CONFIG['errbit_host'] || 'YOUR_ERRBIT_HOST'
  config.development_environments = if CONFIG['errbit_api_key'].blank?
    "production development test"
  else
    "development test"
  end

  config.ignore_only = %w{
  ActiveRecord::RecordNotFound
  ActionController::InvalidAuthenticityToken
  CGI::Session::CookieStore::TamperedWithCookie
  ActionController::UnknownAction
  AbstractController::ActionNotFound
  ActionView::MissingTemplate
  Timeout::Error
  Net::HTTPBadResponse
  WebuiMatcher::InvalidRequestFormat
  ActionController::UnknownFormat
  ActivXML::Transport::NotFoundError
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
