# frozen_string_literal: true
ThinkingSphinx::Index.define :project, with: :active_record do
  indexes name, title, description

  has :id, as: :project_id
  has attribs.attrib_type_id, as: :attrib_type_ids
  has packages.package_issues.issue_id, as: :issue_ids
  has '(SELECT count(*) FROM linked_projects WHERE linked_db_project_id = projects.id)', as: :linked_count, type: :integer
  has '(SELECT max(activity_index) FROM packages WHERE '\
        'project_id = projects.id '\
        'AND NOT EXISTS (SELECT * FROM packages p WHERE p.project_id = projects.id AND p.updated_at > packages.updated_at))',
      as: :activity_index, type: :float
  has 'EXISTS (SELECT * FROM linked_projects WHERE db_project_id = projects.id)', as: :links_to_other, type: :boolean
  has 'EXISTS (SELECT * FROM packages INNER JOIN packages p ON p.id = packages.develpackage_id WHERE p.project_id = projects.id)',
      as: :is_devel, type: :boolean
  has '(SELECT max(updated_at) FROM packages WHERE project_id = projects.id)', as: :updated_at, type: :timestamp
end
