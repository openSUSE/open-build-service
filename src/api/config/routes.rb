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
  # map.connect ':controller/service.wsdl', :action => 'wsdl'

  map.connect '/', :controller => 'main'

  map.connect 'person/register', :controller => 'person', :action => 'register'
  map.connect 'person/:login', :controller => 'person', :action => 'userinfo'

  map.connect 'rpm/:project/:repository/:arch/:package/history',
    :controller => 'rpm',
    :action => 'pass_to_repo'

  map.connect 'rpm/:project/:repository/:arch/:package/buildinfo',
    :controller => 'rpm',
    :action => 'buildinfo'

  map.connect 'rpm/:project/:repository/:arch/:package/status',
    :controller => 'rpm',
    :action => 'pass_to_repo'

  map.connect 'rpm/:project/:repository/:package/:arch/:file',
    :controller => 'rpm',
    :action => 'file'

  
  map.connect 'result/:project/result', :controller => 'result',
    :action => 'projectresult'
  map.connect 'result/:project/packstatus', :controller => 'result',
    :action => 'packstatus'
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

  map.connect '/active_rbac/registration/confirm/:user/:token',
              :controller => 'active_rbac/registration',
              :action => 'confirm'

  # Install the default route as the lowest priority.
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action'
end
