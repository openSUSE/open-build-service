xml.collection do
  @owners.each do |o|

    attribs={}
    attribs[:rootproject] = o[:rootproject]
    attribs[:project] = o[:project]
    attribs[:package] = o[:package] if o[:package]
    xml.owner(attribs) do

      o[:filter].each do |f|
        xml.filter f.pluralize
      end

    end
  end
end

