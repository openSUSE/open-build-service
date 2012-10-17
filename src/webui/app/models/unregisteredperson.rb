class Unregisteredperson < ActiveXML::Node

  default_find_parameter :login
  class << self
    def make_stub( opt )
      realname = ""
      realname = opt[:realname] if opt.has_key? :realname
      email = ""
      email = opt[:email] if opt.has_key? :email
      password = "opensuse"
      password = opt[:password] if opt.has_key? :password

      # This is the place where we decide in which state users are created.
      # Change the following line to 
      #  state = 5
      # to set the initial state of the user to unconfirmned. That means that
      # the user can not work yet but has to wait until somebody from the admin
      # team has acknowledged the user.
      state = 2
      
      note = opt[:explanation]
      
      reply = <<-ENDE
        <unregisteredperson>
           <login>#{opt[:login]}</login>
           <realname>#{realname}</realname>
           <email>#{email}</email>
           <state>#{state}</state>
           <password>#{password}</password>
           <note>#{note}</note>
        </unregisteredperson>
      ENDE

      return reply
    end
  end
end
