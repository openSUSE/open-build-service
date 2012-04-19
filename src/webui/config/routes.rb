OBSWebUI::Application.routes.draw do

  controller :main do 
    match '/' => :index
    match '/main/systemstatus' => :systemstatus
    match '/main/news' => :news
    match '/main/latest_updates' => :latest_updates
    match '/main/sitemap' => :sitemap
    match '/main/sitemap_projects' => :sitemap_projects
    match '/main/sitemap_projects_subpage' => :sitemap_projects_subpage
    match '/main/sitemap_projects_packages' => :sitemap_projects_packages
    match '/main/sitemap_projects_prjconf' => :sitemap_projects_prjconf
    match '/main/sitemap_packages' => :sitemap_packages
    match '/main/add_news_dialog' => :add_news_dialog
    match '/main/add_news' => :add_news
    match '/main/delete_message_dialog' => :delete_message_dialog
    match '/main/delete_message' => :delete_message
  end

  controller :user do
    match '/user/do_login' => :do_login
    match '/user/edit' => :edit
    match '/user/register' => :register
    match '/user/login' => :login
    match '/user/logout' => :logout
    match '/user/save' => :save
    match '/user/change_password' => :change_password
    match '/user/autocomplete' => :autocomplete
  end

  controller :package do
    match ':project/:repository/:pkgrev' => :files, :requirements => { :project => /[^\/]+/, :repository => /[^\/]+/, :pkgrev => /[a-fA-F0-9]{32}-(.+)/ }

  end

  resources :groups, :controller => 'group', :only => [:index, :show]

  #TODO: Get rid of default routes and either add them by hand or use resources:
  match ':controller(/:action(/:id))(.:format)'
end
