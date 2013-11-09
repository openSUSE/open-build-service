require 'activexml/activexml'

map = ActiveXML::setup_transport_api(CONFIG['frontend_protocol'], CONFIG['frontend_host'], CONFIG['frontend_port'])

    map.connect :webuiproject, 'rest:///source/:name/_meta?:view',
      :delete => 'rest:///source/:name?:force',
      :issues => 'rest:///source/:name?view=issues'
    map.connect :webuipackage, 
	        'rest:///source/:project/:name/_meta?:view',
                 :issues => 'rest:///source/:project/:name?view=issues'

    map.connect :webuigroup, 'rest:///group/:title',
      :all => 'rest:///group/'

    map.connect :webuirequest, 'rest:///request/:id', :create => 'rest:///request?cmd=create'

  map.set_additional_header( 'User-Agent', "obs-webui/#{CONFIG['version']}" )
  map.set_additional_header( 'Accept', 'application/xml' )

