xml.package( project: @package.project.name, name: @package.name ) do
  @package.package_kinds.each do |k|
    xml.kind(k.kind)
  end
  # issues defined in sources
  issues = @package.package_issues
  # add issues defined in attributes
  @package.attribs.each do |attr|
    next unless attr.attrib_type.issue_list
    issues += attr.issues
  end
  render partial: 'common_issues', locals: { builder: xml, issues: issues }
end