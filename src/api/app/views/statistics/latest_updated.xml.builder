
xml.latest_updated do
  @list.each do |item|
    ### item is a package
    if item[1] == :package
      xml.package(
        :name => item[2],
        :project => item[3],
        :updated => item[0].xmlschema
      )
    else
      ### item is a project
      xml.project(
        :name => item[1],
        :updated => item[0].xmlschema
      )
    end
  end
end

