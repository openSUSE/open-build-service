OBSApi::Application.routes.draw do
  constraints(RoutesHelper::WebuiMatcher) do
    draw :webui
  end
  constraints(RoutesHelper::APIMatcher) do
    draw :api
  end
end
