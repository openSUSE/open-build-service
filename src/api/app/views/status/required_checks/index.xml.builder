xml.required_checks(build_header(@project, @checkable)) do
  @required_checks.each do |name|
    xml.name(name)
  end
end
