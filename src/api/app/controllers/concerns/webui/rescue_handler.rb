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
        redirect_back(fallback_location: root_path)
      end
    end

    rescue_from Package::Errors::ScmsyncReadOnly do |exception|
      if request.xhr?
        render json: { error: exception.default_message }, status: exception.status
      else
        flash[:error] = exception.default_message
        redirect_back(fallback_location: root_path)
      end
    end

    # FIXME: just because there is some data missing to compute the request?
    # Please check:
    # http://guides.rubyonrails.org/active_record_validations.html
    class MissingParameterError < RuntimeError; end
    rescue_from MissingParameterError do |exception|
      logger.debug "#{exception.class.name} #{exception.message} #{exception.backtrace.join('\n')}"
      render file: Rails.public_path.join('404.html'), status: :not_found, layout: false, formats: [:html]
    end
  end
end
