xml.collection do
  @assignees.each do |a|

    attribs={}
    attribs[:project] = a[:project]
    attribs[:package] = a[:package] if a[:package]
    xml.owner(attribs) do

      roles = []
      roles += a[:users].keys  if a[:users]
      roles += a[:groups].keys if a[:groups]

      roles.each do |role|
        if a[:users]
          xml.send(role) do
            a[:users][role].each do |user|
              xml.user user
            end
          end
        end
        if a[:groups]
          xml.send(role) do
            a[:groups][role].each do |group|
              xml.group group
            end
          end
        end
      end
    end
  end
end

