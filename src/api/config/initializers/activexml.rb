require_dependency 'activexml/activexml'

CONFIG['source_protocol'] ||= 'http'

ActiveXML.setup_transport_backend(CONFIG['source_protocol'], CONFIG['source_host'], CONFIG['source_port'])
