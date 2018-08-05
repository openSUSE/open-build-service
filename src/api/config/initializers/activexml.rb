require_dependency 'activexml/activexml'

CONFIG['source_protocol'] ||= 'http'

map = ActiveXML.setup_transport_backend(CONFIG['source_protocol'], CONFIG['source_host'], CONFIG['source_port'])

map.connect :directory, 'rest:///source/:project/:package?:expand&:rev&:meta&:linkrev&:emptylink&:view&:extension&:lastworking&:withlinked&:deleted'
map.connect :jobhistory, 'rest:///build/:project/:repository/:arch/_jobhistory?:package&:limit&:code'

map.connect :collection, 'rest:///search/:what?:match',
            id: 'rest:///search/:what/id?:match',
            package: 'rest:///search/package?:match',
            project: 'rest:///search/project?:match'

map.connect :buildresult, 'rest:///build/:project/_result?:view&:package&:code&:lastbuild&:arch&:repository&:multibuild&:locallink'

map.connect :statistic, 'rest:///build/:project/:repository/:arch/:package/_statistics'

map.connect :service, 'rest:///source/:project/:package/_service?:user'
