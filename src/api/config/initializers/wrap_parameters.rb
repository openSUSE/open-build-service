# Be sure to restart your server when you modify this file.
#
# This file contains settings for ActionController::ParamsWrapper which
# is enabled by default.
require 'active_support/core_ext/hash/conversions'
require 'action_dispatch/http/request'
require 'active_support/core_ext/hash/indifferent_access'
require 'api_exception'

# Disable all default rails parameter parsing

ActiveSupport.on_load(:action_controller) do
  wrap_parameters(false) if respond_to?(:wrap_parameters)
end

# Disable root element in JSON by default.
ActiveSupport.on_load(:active_record) do
  self.include_root_in_json = false
end

OBSApi::Application.config.middleware.delete 'ActionDispatch::ParamsParser'

# custom params parser (modified form of ActionDispatch::ParamsParser)

class MyParamsParser
  class ParseError < APIError
  end

  def initialize(app)
    @app = app
  end

  def call(env)
    params = parse_parameters(env)
    env['action_dispatch.request.request_parameters'] = params if params

    env['HTTP_ACCEPT'] ||= 'application/xml'
    @app.call(env)
  end

  def parse_parameters(env)
    request = ActionDispatch::Request.new(env)

    return false if request.content_length.zero?

    case request.content_mime_type
    when Mime[:json]
      begin
        data = ActiveSupport::JSON.decode(request.raw_post)
      rescue JSON::ParserError => e
        Rails.logger.info "failed to parse JSON: #{e.message}"
        return false
      end
      request.body.rewind if request.body.respond_to?(:rewind)
      data = { _json: data } unless data.is_a?(Hash)
      data.with_indifferent_access
    when Mime[:xml]
      data = Xmlhash.parse(request.body.read)
      request.body.rewind if request.body.respond_to?(:rewind)
      if data
        { xmlhash: data }.with_indifferent_access
      else
        false
      end
    else
      false
    end
  end
end

OBSApi::Application.config.middleware.use(MyParamsParser)
