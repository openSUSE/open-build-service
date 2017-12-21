# the default render json: uses to_json from json gem using the pure variant
# which has horrible performance - see https://github.com/rails/rails/issues/9212
require 'yajl'

ActionController::Renderers.add :json do |json, _|
  json = Yajl::Encoder.encode(json) unless json.is_a?(String)
  self.content_type ||= Mime[:json]
  json
end
