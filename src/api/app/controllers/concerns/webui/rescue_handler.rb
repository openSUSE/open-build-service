# NOTE: There is also ApplicationController.render_error which will handle APIError
# exceptions that will happen while requesting HTML from the API
module Webui::RescueHandler
  extend ActiveSupport::Concern

  included do
    rescue_from Backend::Error, Timeout::Error do |exception|
      Airbrake.notify(exception)
      message = case exception
                when Backend::Error
                  'There has been an internal error. Please try again.'
                when Timeout::Error
                  'The request timed out. Please try again.'
                end

      if request.xhr?
        render json: { error: message }, status: :bad_request
      else
        flash[:error] = message
        redirect_back_or_to root_path
      end
    end

    rescue_from Project::Errors::UnknownObjectError, Package::Errors::UnknownObjectError, Package::Errors::ReadSourceAccessError, Package::Errors::ScmsyncReadOnly do |exception|
      message = exception.message || exception.default_message
      if request.xhr?
        head :not_found
      else
        flash[:error] = message
        redirect_back_or_to root_path
      end
    end

    rescue_from AjaxDatatablesRails::Error::InvalidSearchColumn, AjaxDatatablesRails::Error::InvalidSearchCondition do
      render json: { data: [] }
    end

    rescue_from AuthenticationFailed, AuthenticationRequiredError do |exception|
      case CONFIG['proxy_auth_mode']
      when :mellon
        redirect_to add_return_to_parameter_to_query(url: CONFIG['proxy_auth_login_page'], parameter_name: 'ReturnTo')
      when :ichain
        redirect_to add_return_to_parameter_to_query(url: CONFIG['proxy_auth_login_page'], parameter_name: 'url')
      when :on
        redirect_to CONFIG['proxy_auth_login_page']
      else # no proxy auth
        reset_session
        redirect_to(new_session_path, error: exception.default_message)
      end
    end

    rescue_from UnconfirmedUserError, InactiveUserError, ErrRegisterSave do |exception|
      if ::Configuration.proxy_auth_mode_enabled?
        redirect_to('/402')
      else
        reset_session
        redirect_to(new_session_path, error: exception.default_message)
      end
    end

    def add_return_to_parameter_to_query(url:, parameter_name:)
      uri = URI(url)
      return_to = {}
      return_to[parameter_name] = request.fullpath
      query_array = uri.query.to_s.split('&')
      query_array << return_to.to_query # for URL encoding
      uri.query = query_array.join('&')

      uri.to_s
    end
  end
end
