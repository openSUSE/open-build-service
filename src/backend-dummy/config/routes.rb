ActionController::Routing::Routes.draw do |map|
  # Add your own custom routes here.
  # The priority is based upon order of creation: first created -> highest priority.
  
  # Here's a sample route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # You can have the root of your site routed by hooking up '' 
  # -- just remember to delete public/index.html.
  # map.connect '', :controller => "welcome"

  # Allow downloading Web Service WSDL as a file with an extension
  # instead of a file named 'wsdl'
  
  
  # setting routes for source controller
  map.connect 'source/:project/_meta', :controller => 'source',
    :action => 'project_meta'
  map.connect 'source/:project/:package/_meta', :controller => 'source',
    :action => 'package_meta'
  map.connect 'source/:project/:package/:file', :controller => "source",
    :action => 'file'
  map.connect 'source/:project/:package', :controller => "source",
    :action => 'filelist'
  map.connect 'source/:project', :controller => "source", :action => 'packagelist'
  map.connect 'source', :controller => "source"
  
  
  # setting routes for platform controller
  map.connect 'platform/:project/:repository', :controller => 'platform',
    :action => 'repository'
  map.connect 'platform/:project', :controller => 'platform',
    :action => 'project'
  map.connect 'platform', :controller => 'platform'
    

  map.connect 'admin/:action', :controller => 'admin'

  map.connect 'rpm/:project/:platform/:file', :controller => 'rpm',
    :action => 'file'

  map.connect 'result/:project/:platform/:file', :controller => 'result',
    :action => 'file'
  map.connect 'result/:project/:file', :controller => 'result',
    :action => 'file'

  # Install the default route as the lowest priority.
  # map.connect ':controller/:action/:id'
end
