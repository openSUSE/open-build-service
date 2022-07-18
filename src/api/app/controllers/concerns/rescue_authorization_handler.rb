module RescueAuthorizationHandler
  extend ActiveSupport::Concern

  included do # rubocop:disable Metrics/BlockLength
    rescue_from Pundit::NotAuthorizedError do |exception|
      if RoutesHelper::APIMatcher.matches?(request)
        render_error status: 403,
                     errorcode: authorization_errorcode(exception),
                     message: authorization_message(exception)
      else
        respond_to do |format|
          format.js { render json: { error: authorization_message(exception) }, status: 400 }
          format.any do
            flash[:error] = authorization_message(exception)
            redirect_path = unauthorized_redirect_path(exception)
            if redirect_path
              redirect_to(redirect_path)
            else
              redirect_back(fallback_location: root_path)
            end
          end
        end
      end
    end

    private

    def action_for_exception(exception)
      case exception.query.to_s.chop
      when 'index' then 'list'
      when 'show' then 'view'
      when 'new' then 'create'
      when 'destroy' then 'delete'
      else exception.query.to_s.chop
      end
    end

    def authorization_errorcode(exception)
      "#{action_for_exception(exception)}_#{ActiveSupport::Inflector.underscore(exception.record.class.to_s)}_not_authorized"
    end

    def authorization_message(exception)
      case exception.reason
      when :anonymous_user
        'Please login to access the resource'
      else
        "Sorry, you are not authorized to #{action_for_exception(exception)} this #{ActiveSupport::Inflector.underscore(exception.record.class.to_s).humanize(capitalize: false)}."
      end
    end

    def unauthorized_redirect_path(exception)
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
