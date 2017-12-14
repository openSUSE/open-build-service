xml.collection do
  @owners.each do |o|
    attribs = {}
    attribs[:rootproject] = o[:rootproject]
    attribs[:project] = o[:project]
    attribs[:package] = o[:package] if o[:package]
    xml.owner(attribs) do
      roles = []
      roles += o[:users].keys  if o[:users]
      roles += o[:groups].keys if o[:groups]
      roles.uniq!

      roles.each do |role|
        if o[:users] && o[:users][role]
          o[:users][role].each do |user|
            xml.person(:name => user, :role => role)
          end
        end
        if o[:groups] && o[:groups][role]
          o[:groups][role].each do |group|
            xml.group(:name => group, :role => role)
          end
        end
      end
    end
  end
end

