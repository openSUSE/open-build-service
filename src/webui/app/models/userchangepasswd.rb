
class Userchangepasswd < ActiveXML::Node
  class << self
    def make_stub( opt )
      login = ""
      login = opt[:login] if opt.has_key? :login
      password = ""
      password = opt[:password] if opt.has_key? :password
      
      reply = <<-ENDE
        <userchangepasswd>
           <login>#{login}</login>
           <password>#{password}</password>
        </userchangepasswd>
      ENDE
      return reply
    end
  end
end
