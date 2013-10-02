class Webui::Unregisteredperson < Webui::Node

  default_find_parameter :login
  class << self
    def make_stub( opt )
      realname = ""
      realname = opt[:realname] if opt.has_key? :realname
      email = ""
      email = opt[:email] if opt.has_key? :email
      password = "opensuse"
      password = opt[:password] if opt.has_key? :password
      state = ""
      state = opt[:state] if opt.has_key? :state

      reply = <<-END
        <unregisteredperson>
           <login>#{opt[:login]}</login>
           <realname>#{realname}</realname>
           <email>#{email}</email>
           <state>#{state}</state>
           <password>#{password}</password>
        </unregisteredperson>
      END

      return reply
    end
  end
end
