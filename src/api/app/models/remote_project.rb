# A project that has a remote url set
class RemoteProject < Project
  default_scope { where.not(remoteurl: nil) }

  validates :title, :description, :remoteurl, presence: true
  validate :exists_by_name_validation

  CACHE_EXPIRATION = 1.hour

  def exists_by_name_validation
    return unless Project.exists_by_name(name)

    errors.add(:name, 'already exists')
  end

  def load_templates(path, cache_key)
    Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRATION) do
      Project::RemoteURL.load(self, path)
    end
  end

  def build_template_project_from_xml(template_project, template_type)
    project = Project.new(name: "#{name}:#{template_project['name']}")
    template_project.elements("#{template_type}_template_package").each do |template_package|
      project.packages.new(
        name: template_package['name'].presence,
        title: template_package['title'].presence,
        description: template_package['description'].presence
      )
    end
    project
  end

  class << self
    def fetch_templates(template_type, remote_xml)
      all.each_with_object([]) do |project, result|
        body = project.load_templates(remote_xml, "remote_#{template_type}_templates_#{project.id}")
        next if body.blank?

        Xmlhash.parse(body).elements("#{template_type}_template_project").each do |template_project|
          result << project.build_template_project_from_xml(template_project, template_type)
        end
      end
    end

    def image_templates
      fetch_templates(:image, '/image_templates.xml')
    end

    def package_templates
      fetch_templates(:package, '/package_templates.xml')
    end
  end
end

# == Schema Information
#
# Table name: projects
#
#  id                            :integer          not null, primary key
#  anitya_distribution_name      :string(255)
#  anitya_distribution_synced_at :datetime
#  comments_count                :integer          default(0), not null, indexed
#  delta                         :boolean          default(TRUE), not null
#  description                   :text(65535)
#  kind                          :string           default("standard")
#  name                          :string(200)      not null, uniquely indexed
#  remoteproject                 :string(255)
#  remoteurl                     :string(255)
#  report_bug_url                :string(8192)
#  required_checks               :string(255)
#  scmsync                       :text(65535)
#  title                         :string(255)
#  url                           :string(255)
#  created_at                    :datetime
#  updated_at                    :datetime
#  develproject_id               :integer          indexed
#  staging_workflow_id           :integer          indexed
#
# Indexes
#
#  devel_project_id_index                 (develproject_id)
#  index_projects_on_comments_count       (comments_count)
#  index_projects_on_staging_workflow_id  (staging_workflow_id)
#  projects_name_index                    (name) UNIQUE
#
