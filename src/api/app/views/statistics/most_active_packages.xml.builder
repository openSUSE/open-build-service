

xml.most_active do
  @packages.each do |package|
    xml.package(
      :activity => package.activity_value,
      :project => package.project.name,
      :name => package.name
    )
  end
end

