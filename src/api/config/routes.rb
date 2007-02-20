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
  map.connect 'person/:login/_roles', :controller => 'person', :action => 'roleinfo'
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
  map.connect 'source/:project/_config', :controller => 'source',
    :action => 'project_config'
  map.connect 'source/:project/:package/_meta', :controller => 'source',
    :action => 'package_meta'

  #routes for tagging support  
  #
  # map.connect 'tag/_all', :controller => 'tag',
  #  :action => 'list_xml'
  #Get/put tags by object
  	map.connect 'source/:project/_tags', :controller => 'tag',
      :action => 'project_tags'
	map.connect 'source/:project/:package/_tags', :controller => 'tag',
      :action => 'package_tags'   
  
  #Get objects by tag.
    map.connect 'tag/:tag/_projects', :controller => 'tag',
      :action => 'get_projects_by_tag'
    map.connect 'tag/:tag/_packages', :controller => 'tag',
      :action => 'get_packages_by_tag'
    map.connect 'tag/:tag/_all', :controller => 'tag',
      :action => 'get_objects_by_tag'
 
  #Get objects tagged by user. (objects with tags)
    map.connect 'user/:user/tags/_projects', :controller => 'tag',
      :action => 'get_tagged_projects_by_user'
    map.connect 'user/:user/tags/_packages', :controller => 'tag',
      :action => 'get_tagged_packages_by_user'
  
  #Get tags by user.	
    map.connect 'user/:user/tags/_tagcloud', :controller => 'tag',
      :action =>  'tagcloud'
    #map.connect 'user/:user/tags', :controller => 'tag',
    #  :action => 'tagcloud', :distribution => 'raw'
  
  #Get tags for a certain object by user.
    map.connect 'user/:user/tags/:project', :controller => 'tag',
      :action => 'tags_by_user_and_object'  
    map.connect 'user/:user/tags/:project/:package', :controller => 'tag',
      :action => 'tags_by_user_and_object'  
  
  #Get a tagcloud including all tags.
    map.connect 'tag/_tagcloud', :controller => 'tag',
    :action => 'tagcloud'


  # Routes for statistics
  # ---------------------

  # Download statistics
  #
  map.connect 'statistics/download_counter/:project',
    :controller => 'statistics', :action => 'download_counter'
  map.connect 'statistics/download_counter/:project/:package',
    :controller => 'statistics', :action => 'download_counter'
  map.connect 'statistics/download_counter/:project/:package/:repository',
    :controller => 'statistics', :action => 'download_counter'
  map.connect 'statistics/download_counter/:project/:package/:repository/:architecture',
    :controller => 'statistics', :action => 'download_counter'


  # Routes for status_messages
  # --------------------------
  map.connect 'status_message/:id',
    :controller => 'status_message', :action => 'index'


  map.connect 'source/:project/:package/:file', :controller => "source",
    :action => 'file'
    
  map.connect 'source/:project/:package', :controller => "source",
    :action => 'index_package'
  map.connect 'source/:project', :controller => "source",
    :action => 'index_project'

  map.connect 'search/project/id', :controller => "search", :action => "project_id"
  map.connect 'search/package/id', :controller => "search", :action => "package_id"
  map.connect 'search/project', :controller => "search", :action => "project"
  map.connect 'search/package', :controller => "search", :action => "package"
  map.connect 'search', :controller => "search", :action => "pass_to_source"

  map.connect 'build/:project/:repository/:arch/:package/_status',
        :controller => "build", :action => "pass_to_source"
  map.connect 'build/:project/:repository/:arch/:package/_log',
        :controller => "build", :action => "pass_to_source"
  map.connect 'build/:project/:repository/:arch/:package/_buildinfo',
        :controller => "build", :action => "pass_to_source"
  map.connect 'build/:project/:repository/:arch/:package/:filename',
        :controller => "build", :action => "pass_to_source"
  map.connect 'build/:project/:repository/:arch/:package',
        :controller => "build", :action => "pass_to_source"
  map.connect 'build/:project/:repository/_buildconfig',
        :controller => "build", :action => "pass_to_source"
  map.connect 'build/:project/:repository/:arch',
        :controller => "build", :action => "pass_to_source"
  map.connect 'build/:project/_result',
        :controller => "build", :action => "pass_to_source"
  map.connect 'build/:project/:repository',
        :controller => "build", :action => "pass_to_source"
  map.connect 'build/:project',
        :controller => "build", :action => "pass_to_source"
  map.connect 'build/_workerstatus',
        :controller => "build", :action => "pass_to_source"
  map.connect 'build',
        :controller => "build", :action => "pass_to_source"


    

  map.apidocs 'apidocs/', :controller => "apidocs"

  map.connect '/active_rbac/registration/confirm/:user/:token',
              :controller => 'active_rbac/registration',
              :action => 'confirm'

  # Install the default route as the lowest priority.
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action'
end
