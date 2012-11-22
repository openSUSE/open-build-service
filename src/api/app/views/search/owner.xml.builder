xml.collection do
  @assignees.each do |a|

    attribs={}
    attribs[:rootproject] = a[:rootproject]
    attribs[:project] = a[:project]
    attribs[:package] = a[:package] if a[:package]
    xml.owner(attribs) do

      roles = []
      roles += a[:users].keys  if a[:users]
      roles += a[:groups].keys if a[:groups]

      roles.each do |role|
        if a[:users] and a[:users][role]
          a[:users][role].each do |user|
            xml.person( :name => user, :role => role )
          end
        end
        if a[:groups] and a[:groups][role]
          a[:groups][role].each do |group|
          xml.group( :name => group, :role => role )
          end
        end
      end
    end
  end
end

