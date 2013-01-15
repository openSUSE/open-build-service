xml.collection do
  @owners.each do |o|

    attribs={}
    attribs[:rootproject] = o[:rootproject]
    attribs[:project] = o[:project]
    attribs[:package] = o[:package] if o[:package]
    xml.owner(attribs) do

      roles = []
      roles += o[:users].keys  if o[:users]
      roles += o[:groups].keys if o[:groups]

      roles.each do |role|
        if o[:users] and o[:users][role]
          o[:users][role].each do |user|
            u = User.find_by_login user
            xml.person do 
              xml.login user
              xml.email u.email
              xml.realname u.realname
            end
          end
        end
        if o[:groups] and o[:groups][role]
          o[:groups][role].each do |group|
          xml.group
            xml.name group
          end
        end
      end
    end
  end
end

