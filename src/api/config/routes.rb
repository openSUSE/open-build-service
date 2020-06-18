class ActionDispatch::Routing::Mapper
  def draw(routes_name)
    instance_eval(File.read(Rails.root.join("config/routes/#{routes_name}_routes.rb")))
  end
end

OBSApi::Application.routes.draw do
  draw :webui
  draw :api
end
