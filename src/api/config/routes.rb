OBSApi::Application.routes.draw do
  mount Peek::Railtie => '/peek'
  require_relative 'routes/routes_helper'
  require_relative 'routes/webui_routes'
  require_relative 'routes/api_routes'
end

OBSEngine::Base.subclasses.each(&:mount_it)
