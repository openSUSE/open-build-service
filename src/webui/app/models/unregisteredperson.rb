class Unregisteredperson < ActiveXML::Base

  default_find_parameter :login
  class << self
    def make_stub( opt )
      realname = ""
      if opt.has_key? :realname
        realname = opt[:realname]
      end
      email = ""
      if opt.has_key? :email
        email = opt[:email]
      end
      state = 5
      
      explain = opt[:explanation]
      
      reply = <<-ENDE
        <unregisteredperson>
           <login>#{opt[:login]}</login>
           <realname>#{realname}</realname>
           <email>#{email}</email>
           <state>#{state}</state>
           <password>opensuse</password>
           <note>#{explain}</note>
        </unregisteredperson>
      ENDE

      return REXML::Document.new( reply ).root
    end
  end
end
