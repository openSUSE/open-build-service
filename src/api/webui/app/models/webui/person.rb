module Webui
class Person < Node

  class ListError < Exception; end

  default_find_parameter :login

  handles_xml_element 'person'

  class << self
    def make_stub( opt )
      logger.debug "make stub params: #{opt.inspect}"
      realname = ""
      realname = opt[:realname] if opt.has_key? :realname
      email = ""
      email = opt[:email] if opt.has_key? :email
      state = ""
      state = opt[:state] if opt.has_key? :state
      globalrole = ""
      globalrole = opt[:globalrole] if opt.has_key? :globalrole

      reply = <<-EOF
        <person>
           <login>#{opt[:login]}</login>
           <email>#{email}</email>
           <realname>#{realname}</realname>
           <state>#{state}</state>
           <globalrole>#{globalrole}</globalrole>
        </person>
      EOF
      return reply
    end
  end

  def initialize(data)
    super(data)
    @login = self.to_hash["login"]
  end

  def to_str
    login
  end

  def to_s
    login
  end

  def self.list(prefix=nil, hash=nil)
    prefix = URI.encode(prefix)
    user_list = Rails.cache.fetch("user_list_#{prefix.to_s}", :expires_in => 10.minutes) do
      transport ||= ActiveXML::api
      path = "/person?prefix=#{prefix}"
      begin
        logger.debug 'Fetching user list from API'
        response = transport.direct_http URI("#{path}"), :method => 'GET'
        names = []
        if hash
          Webui::Collection.new(response).each do |user|
            user = { 'name' => user.name }
            names << user
          end
        else
          Webui::Collection.new(response).each {|user| names << user.name}
        end
        names
      rescue ActiveXML::Transport::Error => e
        raise ListError, e.summary
      end
    end
    return user_list
  end

end
end
