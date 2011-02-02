module MaintenanceHelper

  # updates packages automatically generated in the backend after submitting a product file
  def create_new_maintenance_incident( maintenanceProject, baseProject = nil, request = nil )
    mi = MaintenanceIncident.new( :maintenance_db_project_id => maintenanceProject.id ) 

    # Get unique, but readable id
    myTime = Time.now.utc
    mi.day   = myTime.day
    mi.month = myTime.month
    mi.year  = myTime.year
    mi.save!

    year_counter = MaintenanceIncident.count( :conditions => ["maintenance_db_project_id = BINARY ? and year = BINARY ?", maintenanceProject.id, mi.year] )

    id_template = "%Y-%C"
    if a = maintenanceProject.find_attribute("OBS", "MaintenanceIdTemplate")
       id_template = a.values[0]
    end

    id_template.gsub!( /%Y/, mi.year.to_s )
    id_template.gsub!( /%M/, mi.month.to_s )
    id_template.gsub!( /%D/, mi.day.to_s )
    id_template.gsub!( /%C/, year_counter.to_s )
    id_template.gsub!( /%g/, mi.id.to_s )
    name = maintenanceProject.name + ":" + id_template

    tprj = nil
    DbProject.transaction do
      tprj = DbProject.new :name => name
      tprj.project_user_role_relationships = maintenanceProject.project_user_role_relationships
      tprj.project_group_role_relationships = maintenanceProject.project_group_role_relationships
      if baseProject
        # copy as much as possible from base project
        tprj.title = baseProject.title
        tprj.description = baseProject.description
        tprj.flags = baseProject.flags
        tprj.repositories = baseProject.repositories
      end
      tprj.store
      mi.db_project_id = tprj.id
      mi.save!
    end

    # copy all packages and project source files from base project
    if baseProject
#FIXME2.3
    end

    return mi
  end

end
