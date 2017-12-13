xml.collection do
  @owners.each do |o|
    attribs = {}
    attribs[:rootproject] = o[:rootproject]
    attribs[:project] = o[:project]
    attribs[:package] = o[:package] if o[:package]
    xml.missing_owner(attribs)
  end
end

