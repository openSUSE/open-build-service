require 'activexml/activexml'

map = ActiveXML::setup_transport_api(CONFIG['frontend_protocol'], CONFIG['frontend_host'], CONFIG['frontend_port'])

    map.connect :webuiproject, 'rest:///source/:name/_meta?:view',
      :all    => 'rest:///source/',
      :delete => 'rest:///source/:name?:force',
      :issues => 'rest:///source/:name?view=issues'
    map.connect :webuipackage, 'rest:///source/:project/:name/_meta?:view',
      :all    => 'rest:///source/:project',
      :issues => 'rest:///source/:project/:name?view=issues'

    map.connect :webuigroup, 'rest:///group/:title',
      :all => 'rest:///group/'

    map.connect :link, 'rest:///source/:project/:package/_link'

    map.connect :collection, 'rest:///search/:what?match=:predicate',
      :id => 'rest:///search/:what/id?match=:predicate',
      :tag => 'rest:///tag/:tagname/:type',
      :tags_by_user => 'rest:///user/:user/tags/:type',
      :hierarchical_browsing => 'rest:///tag/browsing/_hierarchical?tags=:tags'

    map.connect :webuirequest, 'rest:///request/:id', :create => 'rest:///request?cmd=create'

  map.set_additional_header( 'User-Agent', "obs-webui/#{CONFIG['version']}" )
  map.set_additional_header( 'Accept', 'application/xml' )

