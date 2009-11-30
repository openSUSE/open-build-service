require 'xml'

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

      # This is the place where we decide in which state users are created.
      # Change the following line to 
      #  state = 5
      # to set the initial state of the user to unconfirmned. That means that
      # the user can not work yet but has to wait until somebody from the admin
      # team has acknowledged the user.
      state = 2
      
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

      return XML::Parser.string(reply).parse.root
    end
  end
end
