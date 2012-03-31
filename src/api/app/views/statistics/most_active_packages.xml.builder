

xml.most_active do

  @packages.each do |package|
    xml.package(
      :activity => package.activity_value,
      :update_count => package.update_counter,
      :project => package.db_project.name,
      :name => package.name
    )
  end

end

