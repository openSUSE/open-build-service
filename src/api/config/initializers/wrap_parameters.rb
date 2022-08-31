# Be sure to restart your server when you modify this file.

# This file contains settings for ActionController::ParamsWrapper which
# is enabled by default.
require 'action_dispatch/http/request'
require 'active_support/core_ext/hash/indifferent_access'

# Disable all default rails parameter parsing
# Context: https://github.com/rails/rails/blob/39413de44c0e2c0dd2d964be5985b03d8f968a7b/guides/source/3_1_release_notes.md#configinitializerswrap_parametersrb
ActiveSupport.on_load(:action_controller) do
  wrap_parameters(false) if respond_to?(:wrap_parameters)
end

# Disable root element in JSON by default.
# Context: https://github.com/rails/rails/blob/39413de44c0e2c0dd2d964be5985b03d8f968a7b/guides/source/3_1_release_notes.md#configinitializerswrap_parametersrb
ActiveSupport.on_load(:active_record) do
  self.include_root_in_json = false
end

# Redefine JSON parser to use ActiveSupport::HashWithIndifferentAccess
# Define XML parser, since Rails' default parsers only include JSON. This XML parser also uses ActiveSupport::HashWithIndifferentAccess
# Context: https://github.com/rails/rails/blob/04972d9b9ef60796dc8f0917817b5392d61fcf09/actionpack/lib/action_dispatch/http/parameters.rb#L35-L46
original_parsers = ActionDispatch::Request.parameter_parsers

json_parser = lambda do |raw_post|
  original_parsers[Mime[:json].symbol].call(raw_post).with_indifferent_access
end

xml_parser = lambda do |raw_post|
  data = Xmlhash.parse(raw_post)
  if data
    { xmlhash: data }.with_indifferent_access
  else
    {}
  end
end

new_parsers = original_parsers.merge({ Mime[:json].symbol => json_parser, Mime[:xml].symbol => xml_parser })

ActionDispatch::Request.parameter_parsers = new_parsers
