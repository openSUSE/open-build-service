class BranchPackage::LookupIncidentPackage
  def initialize(params)
    @package = params[:package]
    @link_target_project = params[:link_target_project]
  end

  def package
    possible_packages = @link_target_project.maintenance_projects.collect do |mp|
      # only approved maintenance projects
      next unless maintenance_projects.include?(mp.maintenance_project)

      # extract possible packages
      possible_packages(mp.maintenance_project)
    end.flatten
    pkg = nil
    # choose the last one based on the incident number (incremental sequence)
    possible_packages.compact.each do |possible_package|
      pkg = possible_package if pkg.nil? || possible_package.project.name.gsub(/.*:/, '').to_i > pkg.project.name.gsub(/.*:/, '').to_i
    end
    pkg
  end

  def possible_packages(maintenance_project)
    data = incident_packages(maintenance_project)
    data.xpath('collection/package').collect do |e|
      possible_package = Package.find_by_project_and_name(e.attributes['project'].value,
                                                          e.attributes['name'].value)
      next if possible_package.nil? || !incident?(possible_package)

      possible_package
    end
  end

  def incident_packages(maintenance_project)
    incident_packages = Backend::Api::Search.incident_packages(@link_target_project.name, @package.name,
                                                               maintenance_project.name)
    Nokogiri::XML(incident_packages)
  end

  private

  # TODO: there is not a better way to find it?
  def incident?(pkg)
    pkg.project.maintenance_incident? && pkg.project.unreleased?
  end

  def obs_maintenance_project
    @obs_maintenance_project ||= AttribType.find_by_namespace_and_name!('OBS', 'MaintenanceProject')
  end

  def maintenance_projects
    @maintenance_projects ||= Project.joins(:attribs).where(attribs: { attrib_type_id: obs_maintenance_project.id })
  end
end
