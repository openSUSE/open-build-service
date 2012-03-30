require "activexml/activexml"

unless defined?(SOURCE_PROTOCOL) and not SOURCE_PROTOCOL.blank?
  SOURCE_PROTOCOL = "http"
end

ActiveXML::Base.config do |conf|
  conf.lazy_evaluation = true

  conf.setup_transport do |map|
    map.default_server :rest, "#{SOURCE_PROTOCOL}://#{CONFIG['source_host']}:#{CONFIG['source_port']}"

    map.connect :project, "bssql:///"
    map.connect :package, "bssql:///"

    map.connect :directory, "rest:///source/:project/:package?:expand&:rev&:meta&:linkrev&:emptylink&:view&:extension&:lastworking&:withlinked&:deleted"
    map.connect :jobhistory, "rest:///build/:project/:repository/:arch/_jobhistory?:package&:limit&:code"

    #map.connect :project, "rest:///source/:name/_meta",
    #    :all    => "rest:///source/"
    #map.connect :package, "rest:///source/:project/:name/_meta",
    #    :all    => "rest:///source/:project"
    
    map.connect :bsrequest, "rest:///request/:id",
      :all => "rest:///request"

    map.connect :collection, "rest:///search/:what?:match",
      :id => "rest:///search/:what/id?:match",
      :package => "rest:///search/package?:match",
      :project => "rest:///search/project?:match"

  end

  # the default is not to write through, only once the backend started
  # we set this to true
  conf.global_write_through = false if Rails.env.test?

end
