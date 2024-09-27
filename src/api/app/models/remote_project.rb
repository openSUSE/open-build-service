# A project that has a remote url set
class RemoteProject < Project
  validates :title, :description, :remoteurl, presence: true
  validate :exists_by_name_validation

  def exists_by_name_validation
    return unless Project.exists_by_name(name)

    errors.add(:name, 'already exists')
  end
end

# == Schema Information
#
# Table name: projects
#
#  id                  :integer          not null, primary key
#  delta               :boolean          default(TRUE), not null
#  description         :text(65535)
#  kind                :string           default("standard")
#  name                :string(200)      not null, indexed
#  remoteproject       :string(255)
#  remoteurl           :string(255)
#  report_bug_url      :string(8192)
#  required_checks     :string(255)
#  scmsync             :text(65535)
#  title               :string(255)
#  url                 :string(255)
#  created_at          :datetime
#  updated_at          :datetime
#  develproject_id     :integer          indexed
#  staging_workflow_id :integer          indexed
#
# Indexes
#
#  devel_project_id_index                 (develproject_id)
#  index_projects_on_staging_workflow_id  (staging_workflow_id)
#  projects_name_index                    (name) UNIQUE
#
