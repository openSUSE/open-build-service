# A project that has a remote url set
class RemoteProject < Project
  validates :title, :description, :remoteurl, presence: true
  validate :exists_by_name_validation

  def exists_by_name_validation
    return unless Project.exists_by_name(name)
    errors.add(:name, 'already exists.')
  end
end

# == Schema Information
#
# Table name: projects
#
#  id              :integer          not null, primary key
#  name            :text(65535)
#  title           :string(255)
#  description     :text(65535)
#  created_at      :datetime         default("0000-00-00 00:00:00")
#  updated_at      :datetime         default("0000-00-00 00:00:00")
#  remoteurl       :string(255)
#  remoteproject   :string(255)
#  develproject_id :integer
#  delta           :boolean          default("1"), not null
#  kind            :string(20)       default("standard")
#
# Indexes
#
#  devel_project_id_index  (develproject_id)
#  projects_name_index     (name) UNIQUE
#  updated_at_index        (updated_at)
#
