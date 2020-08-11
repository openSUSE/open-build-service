module Webui::RescueHandler
  extend ActiveSupport::Concern

  included do
    rescue_from Pundit::NotAuthorizedError do |exception|
      pundit_action = case exception.try(:query).to_s
                      when 'index?' then 'list'
                      when 'show?' then 'view'
                      when 'create?' then 'create'
                      when 'new?' then 'create'
                      when 'update?' then 'update'
                      when 'edit?' then 'edit'
                      when 'destroy?' then 'delete'
                      when 'create_branch?' then 'create_branch'
                      else exception.try(:query)
                      end
      message = if pundit_action && exception.record
                  "Sorry, you are not authorized to #{pundit_action} this #{exception.record.class}."
                else
                  'Sorry, you are not authorized to perform this action.'
                end
      if request.xhr?
        render json: { error: message }, status: 400
      else
        flash[:error] = message
        redirect_back(fallback_location: root_path)
      end
    end

    rescue_from Backend::Error, Timeout::Error do |exception|
      Airbrake.notify(exception)
      message = case exception
                when Backend::Error
                  'There has been an internal error. Please try again.'
                when Timeout::Error
                  'The request timed out. Please try again.'
                end

      if request.xhr?
        render json: { error: message }, status: 400
      else
        flash[:error] = message
        redirect_back(fallback_location: root_path)
      end
    end

    # FIXME: just because there is some data missing to compute the request?
    # Please check:
    # http://guides.rubyonrails.org/active_record_validations.html
    class MissingParameterError < RuntimeError; end
    rescue_from MissingParameterError do |exception|
      logger.debug "#{exception.class.name} #{exception.message} #{exception.backtrace.join('\n')}"
      render file: Rails.root.join('public/404'), status: 404, layout: false, formats: [:html]
    end
  end
end
