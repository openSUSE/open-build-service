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
    expand_all_projects.map(&:id)
  end

  def expand_all_projects(project_map: {}, allow_remote_projects: false)
    # cycle check
    return [] if project_map[self]

    project_map[self] = 1

    projects = [self]

    # add all linked and indirect linked projects
    linking_to.each do |lp|
      if lp.linked_db_project.nil?
        projects << lp.linked_remote_project_name if allow_remote_projects
      else
        lp.linked_db_project.expand_all_projects(project_map: project_map, allow_remote_projects: allow_remote_projects).each do |p|
          projects << p
        end
      end
    end

    projects
  end

  # return array of [:name, :project_id] tuples
  def expand_all_packages(packages = [], project_map = {}, package_map = {})
    # check for project link cycle
    return [] if project_map[self]

    project_map[self] = 1

    self.packages.joins(:project).pluck(:name, 'projects.name').each do |name, prj_name|
      next if package_map[name]

      packages << [name, prj_name]
      package_map[name] = 1
    end

    # second path, all packages from indirect linked projects
    linking_to.each do |lp|
      if lp.linked_db_project.nil?
        # FIXME: this is a remote project
      else
        lp.linked_db_project.expand_all_packages(packages, project_map, package_map)
      end
    end

    packages.sort_by { |package| package.first.downcase }
  end

  # return array of [:name, :package_id] tuples for all products
  # this function is making the products uniq
  def expand_all_products
    p_map = {}
    products = Product.all_products(self).to_a
    products.each { |p| p_map[p.cpe] = 1 } # existing packages map
    # second path, all packages from indirect linked projects
    linking_to.each do |lp|
      if lp.linked_db_project.nil?
        # FIXME: this is a remote project
      else
        lp.linked_db_project.expand_all_products.each do |p|
          unless p_map[p.cpe]
            products << p
            p_map[p.cpe] = 1
          end
        end
      end
    end

    products
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
    expand_all_projects(allow_remote_projects: true).any?(String)
  end
end
