ThinkingSphinx::Index.define :project, with: :real_time do
  indexes name
  indexes title
  indexes description

  has :id, as: :project_id, type: :integer
  has attribs_attrib_type_ids, as: :attrib_type_ids, type: :integer, multi: true
  has packages_package_issues_ids, as: :issue_ids, type: :integer, multi: true
  has linked_count, as: :linked_count, type: :integer
  has activity_index, as: :activity_index, type: :float
  has linked_projects?, as: :links_to_other, type: :boolean
  has devel_packages?, as: :is_devel, type: :boolean
  has last_package_updated_at, as: :updated_at, type: :timestamp
end
