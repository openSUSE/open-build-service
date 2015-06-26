# The maintenance incident class represents the entry in the database.
#
class MaintenanceIncident < ActiveRecord::Base

  belongs_to :project, class_name: "Project", foreign_key: :db_project_id
  belongs_to :maintenance_db_project, :class_name => "Project"

  def project_name
      unless self.incident_id
        r = MaintenanceIncident.exec_query(["SELECT counter FROM incident_counter WHERE maintenance_db_project_id = ? FOR UPDATE",
                                            self.maintenance_db_project_id]).first
        if r.nil?
          # no counter exists, initialize it and select again
          MaintenanceIncident.exec_query ["INSERT INTO incident_counter(maintenance_db_project_id) VALUES('?')", self.maintenance_db_project_id]

          r = MaintenanceIncident.exec_query(["SELECT counter FROM incident_counter WHERE maintenance_db_project_id = ? FOR UPDATE",
                                              self.maintenance_db_project_id]).first
        end

        # do an atomic increase of counter
        MaintenanceIncident.exec_query ["UPDATE incident_counter SET counter = counter+1 WHERE maintenance_db_project_id = ?", self.maintenance_db_project_id]
        self.incident_id = r[0]
      end
      name = self.maintenance_db_project.name + ":" + self.incident_id.to_s
      name
  end

  def getUpdateinfoCounter(time, template = "%Y-%C", patch_name = nil)

    uc = UpdateinfoCounter.find_or_create(time, self.maintenance_db_project, template)
    IncidentUpdateinfoCounterValue.find_or_create(time, uc, self.project)
  end

  def getUpdateinfoId( id_template, patch_name )
    # this is not used anymore, but we need to keep it for released incidents base on old (OBS 2.5) code
    return self.updateinfo_id if self.updateinfo_id

    # initialize on first run
    counter = getUpdateinfoCounter(Time.now.utc, id_template, patch_name)

    my_id = id_template

    # replace place holders
    my_id.gsub!( /%C/, counter.value.to_s )
    my_id.gsub!( /%Y/, counter.released_at.year.to_s )
    my_id.gsub!( /%M/, counter.released_at.month.to_s )
    my_id.gsub!( /%D/, counter.released_at.day.to_s )
    my_id.gsub!( /%N/, patch_name||"" )
    my_id.gsub!( /%i/, self.incident_id.to_s )
    my_id.gsub!( /%g/, self.id.to_s )

    return my_id
  end

  # execute a sql query + escaped string
  def self.exec_query(query)
    self.connection.execute self.escape_sql query
  end
end
