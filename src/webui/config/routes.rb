ActionController::Routing::Routes.draw do |map|
  # Add your own custom routes here.
  # The priority is based upon order of creation: first created -> highest priority.
  
  # Here's a sample route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  map.connect '/', :controller => 'main'

  map.connect ':project/:repository/:pkgrev', :controller => 'package', :action => 'files', :requirements => { :project => /[^\/]+/, :repository => /[^\/]+/, :pkgrev => /[a-fA-F0-9]{32}-(.+)/ }

  # REST style paths
  # -> disabled, because this doesn't work for project/package names that conatain colons (:)
  #
  #map.connect '/project/show/:project', :controller => 'project', :action => 'show'
  #map.connect '/project/view/:project', :controller => 'project', :action => 'view'
  #
  #map.connect '/package/show/:project/:package', :controller => 'package', :action => 'show'
  #map.connect '/package/view/:project/:package', :controller => 'package', :action => 'view'


  # Install the default route as the lowest priority.
  map.connect ':controller/:action/:id', :action => /[^\/]*/, :id => /[^\/]*/
  map.connect ':controller/:action', :action => /[^\/]*/
end
