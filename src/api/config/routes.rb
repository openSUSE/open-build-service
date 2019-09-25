require_relative 'routes/routes_helper'

class ActionDispatch::Routing::Mapper
  def draw(routes_name)
    instance_eval(File.read(Rails.root.join("config/routes/#{routes_name}_routes.rb")))
  end
end

OBSApi::Application.routes.draw do
  mount Peek::Railtie => '/peek'
  draw :webui
  draw :api
end

OBSEngine::Base.subclasses.each(&:mount_it)
