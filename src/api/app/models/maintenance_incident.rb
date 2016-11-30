# The maintenance incident class represents the entry in the database.
#
class MaintenanceIncident < ApplicationRecord
  belongs_to :project, class_name: "Project", foreign_key: :db_project_id
  belongs_to :maintenance_db_project, class_name: "Project"

  # <project> - The maintenance project
  # target_project - The maintenance incident project
  #
  # Creates a maintenance incident project (target_project), belonging to <project>
  # and a MaintenanceIncident instance that connects both.
  def self.build_maintenance_incident(project, no_access = false, request = nil)
    result = nil
    return result unless project && project.kind == 'maintenance'

    request = { request: request } if request

    Project.transaction do
      result = MaintenanceIncident.new(maintenance_db_project: project)
      target_project = Project.create(name: result.project_name)
      target_project.flags.create(position: 1, flag: 'build', status: 'disable')

      # publish is disabled, just patchinfos get enabled
      target_project.flags.create(flag: 'publish', status: 'disable')
      if no_access
        target_project.flags.create(flag: 'access', status: 'disable')
      end

      # take over roles from maintenance project
      project.relationships.each do |r|
        target_project.relationships.create(user: r.user, role: r.role, group: r.group)
      end

      # set default bugowner if missing
      bugowner = Role.rolecache['bugowner']
      unless target_project.relationships.users.where('role_id = ?', bugowner.id).exists?
        target_project.add_user( User.current, bugowner )
      end

      # and write it
      target_project.kind = 'maintenance_incident'
      target_project.store(request)
      result.db_project_id = target_project.id
      result.save!
    end
    result
  end

  def project_name
      unless incident_id
        r = MaintenanceIncident.exec_query(["SELECT counter FROM incident_counter WHERE maintenance_db_project_id = ? FOR UPDATE",
                                            maintenance_db_project_id]).first
        if r.nil?
          # no counter exists, initialize it and select again
          MaintenanceIncident.exec_query ["INSERT INTO incident_counter(maintenance_db_project_id) VALUES('?')", maintenance_db_project_id]

          r = MaintenanceIncident.exec_query(["SELECT counter FROM incident_counter WHERE maintenance_db_project_id = ? FOR UPDATE",
                                              maintenance_db_project_id]).first
        end

        # do an atomic increase of counter
        MaintenanceIncident.exec_query ["UPDATE incident_counter SET counter = counter+1 WHERE maintenance_db_project_id = ?",
                                        maintenance_db_project_id]
        self.incident_id = r[0]
      end
      name = maintenance_db_project.name + ":" + incident_id.to_s
      name
  end

  def getUpdateinfoCounter(time, template = "%Y-%C")
    uc = UpdateinfoCounter.find_or_create(time, template)
    IncidentUpdateinfoCounterValue.find_or_create(time, uc, project)
  end

  def getUpdateinfoId( id_template, patch_name )
    # this is not used anymore, but we need to keep it for released incidents base on old (OBS 2.5) code
    return updateinfo_id if updateinfo_id

    # initialize on first run
    counter = getUpdateinfoCounter(Time.now.utc, id_template)

    my_id = id_template

    # replace place holders
    my_id.gsub!( /%C/, counter.value.to_s )
    my_id.gsub!( /%Y/, counter.released_at.year.to_s )
    my_id.gsub!( /%M/, counter.released_at.month.to_s )
    my_id.gsub!( /%D/, counter.released_at.day.to_s )
    my_id.gsub!( /%N/, patch_name||"" )
    my_id.gsub!( /%i/, incident_id.to_s )
    my_id.gsub!( /%g/, id.to_s )

    my_id
  end

  # execute a sql query + escaped string
  def self.exec_query(query)
    connection.execute escape_sql query
  end
end
