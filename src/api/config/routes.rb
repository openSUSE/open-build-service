OBSApi::Application.routes.draw do
  devise_for :users
  draw :webui
  draw :api
end
