class BranchPackage::LookupIncidentPackage
  def initialize(params)
    @package = params[:package]
    @link_target_project = params[:link_target_project]
  end

  def last_incident
    incidents = []
    @link_target_project.maintenance_projects.each do |mp|
      # only approved maintenance projects
      next unless maintenance_projects.include?(mp.maintenance_project)
      incidents += possible_incidents(mp.maintenance_project)
    end
    # Get the incident with highest incident number, aka the last incident
    incidents.max
  end

  def possible_incidents(maintenance_project)
    data = incident_packages(maintenance_project)
    data.xpath('collection/package').collect do |e|
      possible_package = Package.find_by_project_and_name(e.attributes['project'].value,
                                                          e.attributes['name'].value)
      next if possible_package.nil?
      next unless incident?(possible_package)
      # "openSUSE:Maintenance:10167".gsub(/.*:/, '').to_i => 10167
      possible_package.project.name.gsub(/.*:/, '').to_i
    end
  end

  def incident_packages(maintenance_project)
    incident_packages = Backend::Api::Search.incident_packages(@link_target_project.name, @package.name,
                                                               maintenance_project.name)
    Nokogiri::XML(incident_packages)
  end

  private

  # TODO: there is not a better way to find it?
  def incident?(package)
    package.project.is_maintenance_incident? && package.project.is_unreleased?
  end

  def obs_maintenance_project
    @obs_maintenance_project ||= AttribType.find_by_namespace_and_name!('OBS', 'MaintenanceProject')
  end

  def maintenance_projects
    @maintenance_projects ||= Project.find_by_attribute_type(obs_maintenance_project)
  end
end
