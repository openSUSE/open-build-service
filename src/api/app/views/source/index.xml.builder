xml.directory do
  @project_names.map do |project_name|
    xml.entry(name: project_name)
  end
end
