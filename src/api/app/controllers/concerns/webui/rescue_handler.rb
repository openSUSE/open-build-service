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
  end
end
