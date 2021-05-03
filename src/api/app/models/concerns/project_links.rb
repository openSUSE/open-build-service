module ProjectLinks
  extend ActiveSupport::Concern

  included do
    has_many :linking_to, -> { order(:position) }, class_name: 'LinkedProject', foreign_key: :db_project_id, dependent: :delete_all
    has_many :projects_linking_to, through: :linking_to, class_name: 'Project', source: :linked_db_project
    has_many :linked_by, -> { order(:position) }, class_name: 'LinkedProject', foreign_key: :linked_db_project_id, dependent: :delete_all
    has_many :linked_by_projects, through: :linked_by, class_name: 'Project', source: :project
  end

  class_methods do
    def validate_link_xml_attribute(request_data, project_name)
      request_data.elements('link') do |e|
        # permissions check
        target_project_name = e.value('project')
        target_project = Project.get_by_name(target_project_name)

        # The read access protection for own and linked project must be the same.
        # ignore this for remote targets
        if target_project.instance_of?(Project) &&
           target_project.disabled_for?('access', nil, nil) &&
           !FlagHelper.xml_disabled_for?(request_data, 'access')
          return {
            error: "Project links work only when both projects have same read access protection level: #{project_name} -> #{target_project_name}"
          }
        end
        logger.debug "Project #{project_name} link checked against #{target_project_name} projects permission"
      end
      {}
    end
  end

  def expand_linking_to
    expand_all_projects(allow_remote_projects: false).map(&:id)
  end

  # replace links to this project with links to the "deleted" project
  def cleanup_linking_projects
    LinkedProject.transaction do
      LinkedProject.where(linked_db_project: self).find_each do |lp|
        id = lp.db_project_id
        lp.destroy
        Rails.cache.delete("xml_project_#{id}")
      end
    end
  end

  def links_to_remote?
    linking_to.where.not(linked_remote_project_name: nil).any?
  end
end
