module ProjectMaintenance
  extend ActiveSupport::Concern

  included do
    # optional
    has_one :maintenance_incident, dependent: :delete, foreign_key: :db_project_id

    # projects can maintain other projects
    has_many :maintained_projects, class_name: 'MaintainedProject', foreign_key: :maintenance_project_id, dependent: :delete_all
    has_many :maintenance_projects, class_name: 'MaintainedProject', dependent: :delete_all

    has_many :incident_updateinfo_counter_values, dependent: :delete_all

    scope :maintenance, -> { where("kind = 'maintenance'") }
    scope :not_maintenance_incident, -> { where("kind <> 'maintenance_incident'") }
    scope :maintenance_incident, -> { where("kind = 'maintenance_incident'") }
    scope :maintenance_release, -> { where("kind = 'maintenance_release'") }
  end

  class_methods do
    def get_maintenance_project # rubocop:disable Naming/AccessorMethodName
      at = AttribType.find_by_namespace_and_name!('OBS', 'MaintenanceProject')
      maintenance_project = Project.joins(:attribs).where(attribs: { attrib_type_id: at.id }).first

      return unless maintenance_project&.check_access?

      maintenance_project
    end

    def get_maintenance_project!
      maintenance_project = get_maintenance_project
      raise Project::Errors::UnknownObjectError, 'There is no project flagged as maintenance project on server and no target in request defined.' unless maintenance_project

      maintenance_project
    end

    def validate_maintenance_xml_attribute(request_data)
      request_data.elements('maintenance') do |maintenance|
        maintenance.elements('maintains') do |maintains|
          target_project_name = maintains.value('project')
          target_project = Project.get_by_name(target_project_name)
          return { error: "No write access to maintained project #{target_project_name}" } unless target_project.instance_of?(Project) && User.possibly_nobody.can_modify?(target_project)
        end
      end
      {}
    end
  end

  def maintained_project_names
    maintained_projects.includes(:project).pluck('projects.name')
  end

  def expand_maintained_projects
    maintained_projects.collect { |mp| mp.project.expand_all_projects }.flatten
  end

  def maintenance_release?
    kind == 'maintenance_release'
  end

  def maintenance_incident?
    kind == 'maintenance_incident'
  end

  def maintenance?
    kind == 'maintenance'
  end

  # Returns maintenance incidents by type for current project (if any)
  def maintenance_incidents
    Project.where('projects.name like ?', "#{name}:%").distinct
           .where(kind: 'maintenance_incident')
           .joins(repositories: :release_targets)
           .where('release_targets.trigger = "maintenance"').includes(target_repositories: :project)
  end

  def maintained_namespace
    default = name.split(':').first

    maintenance_project = Project.get_maintenance_project
    return default unless maintenance_project

    return maintenance_project.name if name.start_with?(maintenance_project.name)

    maintenance_project.maintained_project_names.sort_by(&:length).reverse.find { |maintained_project_name| maintained_project_name.in?(name) } || default
  end
end
