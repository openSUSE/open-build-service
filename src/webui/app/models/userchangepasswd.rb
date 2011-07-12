
class Userchangepasswd < ActiveXML::Base
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
      return ActiveXML::Base.new(reply)
    end
  end
end
