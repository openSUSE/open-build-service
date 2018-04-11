# frozen_string_literal: true

xml.package(project: @tpkg.project.name, name: @tpkg.name) do
  @tpkg.package_kinds.each do |k|
    xml.kind(k.kind)
  end
  # issues defined in sources
  issues = @tpkg.package_issues
  # add issues defined in attributes
  @tpkg.attribs.each do |attr|
    next unless attr.attrib_type.issue_list
    issues += attr.issues
  end
  render partial: 'common_issues', locals: { builder: xml, issues: issues }
end
