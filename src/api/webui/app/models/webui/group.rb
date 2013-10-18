class Webui::Group < Webui::Node
  default_find_parameter :title
  handles_xml_element :group

  class << self
    def make_stub( opt )
      name = ""
      name = opt[:name] if opt.has_key? :name
      members = []
      members = opt[:members].split(',') if opt.has_key? :members
      
      reply = "<group><title>#{opt[:name]}</title>"
      if members.length > 0
        reply << "<person>"
        members.each do |person|
          reply << "<person userid=\"#{person}\"/>"
        end
        reply << "</person>"
      end
      reply << "</group>"
      return reply
    end
  end

  def self.list(prefix=nil, hash=nil)
    prefix = URI.encode(prefix)
    group_list = Rails.cache.fetch("group_list_#{prefix.to_s}", :expires_in => 10.minutes) do
      transport ||= ActiveXML::api
      path = "/group?prefix=#{prefix}"
      begin
        logger.debug "Fetching group list from API"
        response = transport.direct_http URI("#{path}"), :method => "GET"
        names = []
        if hash
          Collection.new(response).each do |user|
            user = { 'name' => user.name }
            names << user
          end
        else
          Collection.new(response).each {|group| names << group.name}
        end
        names
      rescue ActiveXML::Transport::Error => e
        raise ListError, e.summary
      end
    end
    return group_list
  end

end
