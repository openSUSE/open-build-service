module Webui::RescueHandler
  extend ActiveSupport::Concern

  included do
    rescue_from Pundit::NotAuthorizedError do |exception|
      message = unauthorized_message(exception)
      redirect_path = unauthorized_path(exception)

      if request.xhr?
        render json: { error: message }, status: 400
      else
        flash[:error] = message
        if redirect_path
          redirect_to(redirect_path)
        else
          redirect_back(fallback_location: root_path)
        end
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

    private

    UNAUTHORIZED_MESSAGE = 'Sorry, you are not authorized to perform this action.'.freeze
    def unauthorized_message(exception)
      pundit_action = action_for_query(exception.query)

      if exception.reason
        message_for_reason(exception.reason)
      elsif pundit_action && exception.record
        "Sorry, you are not authorized to #{pundit_action} this #{exception.record.class}."
      else
        UNAUTHORIZED_MESSAGE
      end
    end

    def action_for_query(query) # rubocop:disable Metrics/CyclomaticComplexity
      case query.to_s
      when 'index?' then 'list'
      when 'show?' then 'view'
      when 'create?', 'new?' then 'create'
      when 'update?' then 'update'
      when 'edit?' then 'edit'
      when 'destroy?' then 'delete'
      when 'create_branch?' then 'create_branch'
      else query
      end
    end

    def message_for_reason(reason)
      case reason
      when ApplicationPolicy::ANONYMOUS_USER
        request.xhr? ? 'Please login' : 'Please login to access the requested page.'
      else
        UNAUTHORIZED_MESSAGE
      end
    end

    def unauthorized_path(exception)
      case exception.reason
      when :anonymous_user
        mode = CONFIG['proxy_auth_mode'] || :off
        if mode == :off
          new_session_path
        else
          root_path
        end
      end
    end
  end
end
