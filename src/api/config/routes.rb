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
  map.connect ':controller/service.wsdl', :action => 'wsdl'

  map.connect '/', :controller => 'main'

  map.connect 'person/:login', :controller => 'person', :action => 'userinfo'

  map.connect 'rpm/:project/:repository/:package/:arch/:file',
    :controller => 'rpm',
    :action => 'file'


  map.connect 'result/:project/result', :controller => 'result',
    :action => 'projectresult'
  map.connect 'result/:project/:platform/result', :controller => 'result',
    :action => 'projectresult'
  map.connect 'result/:project/:platform/:package/result', :controller => 'result',
    :action => 'packageresult'
  map.connect 'result/:project/:platform/:package/:arch/log',
    :controller => 'result',
    :action => 'log'

  
  map.connect 'platform/:project/:repository', :controller => 'platform',
    :action => 'repository'
  map.connect 'platform/:project', :controller => 'platform',
    :action => 'project'

  map.connect 'source/:project/_meta', :controller => 'source',
    :action => 'project_meta'
  map.connect 'source/:project/:package/_meta', :controller => 'source',
    :action => 'package_meta'

  map.connect 'source/:project/:package/:file', :controller => "source",
    :action => 'file'
    
  map.connect 'source/:project/:package', :controller => "source",
    :action => 'index_package'
  map.connect 'source/:project', :controller => "source",
    :action => 'index_project'


  map.apidocs 'apidocs/', :controller => "apidocs"

  # -----------------------------------------------------------------
  # ActiveRBAC routes

  # map the admin stuff into '/admin/'
  map.connect '/arbac/group/:action/:id',
      :controller => 'active_rbac/group'
  map.connect '/arbac/role/:action/:id',
      :controller => 'active_rbac/role'
  map.connect '/arbac/static_permission/:action/:id',
      :controller => 'active_rbac/static_permission'
  map.connect '/arbac/user/:action/:id',
      :controller => 'active_rbac/user'

  # map the login and registration controller somewhere prettier
  map.connect '/login/:action/:id',
      :controller => 'active_rbac/login'
  map.connect '/register/confirm/:user/:token',
      :controller => 'active_rbac/registration',
      :action => 'confirm'
  map.connect '/register/:action/:id',
      :controller => 'active_rbac/registration'

  # hide '/active_rbac/*'
  map.connect '/active_rbac/*foo',
      :controller => 'main'
  # -----------------------------------------------------------------


  # Install the default route as the lowest priority.
  map.connect ':controller/:action/:id'

end
