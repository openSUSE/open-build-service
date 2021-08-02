module RescueHandler
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordInvalid do |exception|
      render_error status: 400, errorcode: 'invalid_record', message: exception.record.errors.full_messages.join('\n')
    end

    rescue_from Backend::Error do |exception|
      render_error status: exception.code, errorcode: 'uncaught_exception', message: exception.summary
    end

    rescue_from Timeout::Error do |exception|
      render_error status: 408, errorcode: 'timeout_error', message: exception.message
    end

    rescue_from APIError do |exception|
      bt = exception.backtrace.join("\n")
      logger.debug "#{exception.class.name} #{exception.message} #{bt}"
      message = exception.message
      message = exception.default_message if message.blank? || message == exception.class.name
      render_error message: message, status: exception.status, errorcode: exception.errorcode
    end

    rescue_from Backend::Error do |exception|
      text = exception.message
      xml = Nokogiri::XML(text, &:strict).root
      http_status = xml['code'] || 500
      xml['origin'] ||= 'backend'
      text = xml.to_xml
      render plain: text, status: http_status
    end

    rescue_from Project::WritePermissionError do |exception|
      render_error status: 403, errorcode: 'modify_project_no_permission', message: exception.message
    end

    rescue_from Package::WritePermissionError do |exception|
      render_error status: 403, errorcode: 'modify_package_no_permission', message: exception.message
    end

    rescue_from Backend::NotFoundError, ActiveRecord::RecordNotFound do |exception|
      render_error message: exception.message, status: 404, errorcode: 'not_found'
    end

    rescue_from Pundit::NotAuthorizedError do |exception|
      message = 'You are not authorized to perform this action.'

      pundit_action =
        case exception.try(:query).to_s
        when 'index?' then 'list'
        when 'show?' then 'view'
        when 'create?', 'new?' then 'create'
        when 'update?' then 'update'
        when 'edit?' then 'edit'
        when 'destroy?' then 'delete'
        when 'create_branch?' then 'create_branch'
        when 'accept?' then 'accept'
        when 'trigger?' then 'trigger'
        else exception.try(:query)
        end

      message = "You are not authorized to #{pundit_action} this #{ActiveSupport::Inflector.underscore(exception.record.class.to_s).humanize}." if pundit_action && exception.record

      render_error status: 403,
                   errorcode: "#{pundit_action}_#{ActiveSupport::Inflector.underscore(exception.record.class.to_s)}_not_authorized",
                   message: message
    end
  end
end
