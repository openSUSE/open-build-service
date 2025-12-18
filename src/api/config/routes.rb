OBSApi::Application.routes.draw do
  constraints(RoutesHelper::WebuiMatcher) do
    draw :webui
  end
  constraints(RoutesHelper::APIMatcher) do
    draw :api
  end

  # spiders request this, not browsers
  controller 'webui/sitemaps' do
    get 'sitemaps' => :index
    get 'project/sitemap' => :projects
    get 'package/sitemap(/:project_name)' => :packages, as: :package_sitemap
  end
end
