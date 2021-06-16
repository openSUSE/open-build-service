# Airbrake is an online tool that provides robust exception tracking in your Rails
# applications. In doing so, it allows you to easily review errors, tie an error
# to an individual piece of code, and trace the cause back to recent
# changes. Airbrake enables for easy categorization, searching, and prioritization
# of exceptions so that when errors occur, your team can quickly determine the
# root cause.
#
# Configuration details:
# https://github.com/airbrake/airbrake-ruby#configuration
Airbrake.configure do |c|
  c.host = CONFIG['errbit_host'] || ENV['ERRBIT_HOST']
  # You must set both project_id & project_key. To find your project_id and
  # project_key navigate to your project's General Settings and copy the values
  # from the right sidebar.
  # https://github.com/airbrake/airbrake-ruby#project_id--project_key
  c.project_id  = CONFIG['errbit_project_id'] || ENV['ERRBIT_PROJECT_ID']
  c.project_key = CONFIG['errbit_api_key'] || ENV['ERRBIT_API_KEY']
  c.app_version = CONFIG['version']

  # Configures the root directory of your project. Expects a String or a
  # Pathname, which represents the path to your project. Providing this option
  # helps us to filter out repetitive data from backtrace frames and link to
  # GitHub files from our dashboard.
  # https://github.com/airbrake/airbrake-ruby#root_directory
  c.root_directory = Rails.root

  # By default, Airbrake Ruby outputs to STDOUT. In Rails apps it makes sense to
  # use the Rails' logger.
  # https://github.com/airbrake/airbrake-ruby#logger
  c.logger = Rails.logger

  # Configures the environment the application is running in. Helps the Airbrake
  # dashboard to distinguish between exceptions occurring in different
  # environments.
  # NOTE: This option must be set in order to make the 'ignore_environments'
  # option work.
  # https://github.com/airbrake/airbrake-ruby#environment
  c.environment = Rails.env

  # Setting this option allows Airbrake to filter exceptions occurring in
  # unwanted environments such as :test.
  # NOTE: This option *does not* work if you don't set the 'environment' option.
  # https://github.com/airbrake/airbrake-ruby#ignore_environments
  c.ignore_environments = if c.host.blank? || c.project_key.blank? || c.project_id.blank?
                            ['production', 'development', 'test']
                          else
                            ['development']
                          end

  # A list of parameters that should be filtered out of what is sent to
  # Airbrake. By default, all "password" attributes will have their contents
  # replaced.
  # https://github.com/airbrake/airbrake-ruby#blocklist_keys
  c.blacklist_keys = [/password/i, /authorization/i]

  # Alternatively, you can integrate with Rails' filter_parameters.
  # Read more: https://goo.gl/gqQ1xS
  # c.blacklist_keys = Rails.application.config.filter_parameters

  # These are airbrake server features that don't work on errbit
  c.performance_stats = false
  c.query_stats = false
end

# A filter that collects request body information. Enable it if you are sure you
# don't send sensitive information to Airbrake in your body (such as passwords).
# https://github.com/airbrake/airbrake#requestbodyfilter
# Airbrake.add_filter(Airbrake::Rack::RequestBodyFilter.new)

# If you want to convert your log messages to Airbrake errors, we offer an
# integration with the Logger class from stdlib.
# https://github.com/airbrake/airbrake#logger
# Rails.logger = Airbrake::AirbrakeLogger.new(Rails.logger)

def ignore_by_class_and_message?(notice)
  notice[:errors].each do |error|
    return true if error[:type] == 'ActionController::RoutingError' && error[:message].match?(/Required Parameter|\[GET\]|Expected AJAX call/)
    return true if error[:type] == 'Backend::Error' && ignore_by_backend_400_message?(error[:message])
  end

  false
end

def ignore_by_backend_400_message?(message)
  messages_to_ignore = ['<summary>conflict in file', '<summary>unknown request:', '<summary>bad link',
                        '<summary>broken link in', '<summary>bad files', 'does not exist</summary>',
                        'is illegal</summary>', '<summary>service in progress</summary>', '<summary>service error',
                        '<summary>could not apply patch', '<summary>illegal characters</summary>',
                        '<summary>repoid is empty</summary>', '<summary>packid is empty</summary>',
                        '<summary>bad private key</summary>', '<summary>pubkey is already expired</summary>',
                        '<summary>not a RSA pubkey</summary>', ' <summary>self-sig does not expire</summary>'].freeze
  messages_to_ignore.each do |ignored_error_message|
    return true if message.include?(ignored_error_message)
  end

  false
end

def ignore_by_class?(notice)
  exceptions_to_ignore = ['ActiveRecord::RecordNotFound', 'ActionController::InvalidAuthenticityToken',
                          'CGI::Session::CookieStore::TamperedWithCookie', 'ActionController::UnknownAction',
                          'AbstractController::ActionNotFound', 'ActionView::MissingTemplate',
                          'Timeout::Error', 'Net::HTTPBadResponse', 'RoutesHelper::WebuiMatcher::InvalidRequestFormat',
                          'ActionController::UnknownFormat', 'Backend::NotFoundError']

  (notice[:errors].pluck(:type) & exceptions_to_ignore).any?
end

def ignore_exception?(notice)
  ignore_by_class?(notice) || ignore_by_class_and_message?(notice)
end

Airbrake.add_filter do |notice|
  notice.ignore! if ignore_exception?(notice)
end
