# frozen_string_literal: true

ThinkingSphinx::Index.define :package, with: :active_record do
  indexes name, title, description

  has :project_id, as: :project_id
  has attribs.attrib_type_id, as: :attrib_type_ids
  has package_issues.issue_id, as: :issue_ids
  has '(SELECT count(*) FROM backend_packages WHERE links_to_id = packages.id)', as: :linked_count, type: :integer
  has activity_index
  has 'EXISTS (SELECT * FROM backend_packages WHERE package_id = packages.id)', as: :links_to_other, type: :boolean
  has 'EXISTS (SELECT * FROM packages p WHERE p.develpackage_id = packages.id)', as: :is_devel, type: :boolean
  has updated_at
end
