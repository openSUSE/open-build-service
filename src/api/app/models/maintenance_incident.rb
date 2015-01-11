# The maintenance incident class represents the entry in the database.
#
class MaintenanceIncident < ActiveRecord::Base

  belongs_to :project, class_name: "Project", foreign_key: :db_project_id
  belongs_to :maintenance_db_project, :class_name => "Project"

  def project_name
      unless self.incident_id
        r = MaintenanceIncident.escape_sql(
        ["SELECT counter FROM incident_counter WHERE maintenance_db_project_id = ? FOR UPDATE",
          self.maintenance_db_project_id]
          ).first

        if r.nil?
          # no counter exists, initialize it and select again
          MaintenanceIncident.escape_sql(
          ["INSERT INTO incident_counter(maintenance_db_project_id) VALUES('?')",
            self.maintenance_db_project_id]
            )
          r = MaintenanceIncident.escape_sql(
          ["SELECT counter FROM incident_counter WHERE maintenance_db_project_id = ? FOR UPDATE",
            self.maintenance_db_project_id ]
            ).first
        end
        # do an atomic increase of counter
        MaintenanceIncident.escape_sql(
        ["UPDATE incident_counter SET counter = ? WHERE maintenance_db_project_id = ?",
          counter+1,self.maintenance_db_project_id]
          )
        self.incident_id = r[0]
      end
      # is that the self.name or just a local variable?
      #name = self.maintenance_db_project.name + ":" + self.incident_id.to_s
      self.maintenance_db_project.name + ":" + self.incident_id.to_s
  end

  def initUpdateinfoId(template = "%Y-%C", patch_name = nil)
    return if self.released_at


    # set current time, to be used
    self.released_at = Time.now.utc
    self.name = patch_name

    counterType
    values = []

    # Run an atomar counter++ based on the used scheme
    if template =~ /%Y/
      counterType " AND year = ?"
      values << self.released_at.year.to_s
      year =  self.released_at.year.to_s
    else
      counterType = " AND ISNULL(year)"
      year = "NULL"
    end
    if template =~ /%M/
      counterType << " AND month = ?"
      values << self.released_at.month.to_s
      month = self.released_at.month.to_s
    else
      counterType << " AND ISNULL(month)"
      month = "NULL"
    end

    if template =~ /%D/
      counterType << " AND day   = ?"
      values << self.released_at.day.to_s
      day = self.released_at.day.to_s
    else
      counterType << " AND ISNULL(day)"
      day = "NULL"
    end
    if template =~ /%N/
      name = (self.name||"")
      counterType << " AND name   = ?" 
      values << name
    else
      counterType << " AND ISNULL(name)"
      name = "NULL"
    end


    r = MaintenanceIncident.escape_sql([
      "SELECT counter FROM updateinfo_counter WHERE maintenance_db_project_id = ? #{counterType} FOR UPDATE",self.maintenance_db_project.id,counterType,*values
      ]).first

    unless r

      # no counter exists, initialize it and select again
      r = MaintenanceIncident.escape_sql([
        "INSERT INTO updateinfo_counter(maintenance_db_project_id, year, month, day, name) VALUES(?,?,?,?,?)",self.maintenance_db_project.id,year,month,day,name
        ])

      r = MaintenanceIncident.escape_sql([
        "SELECT counter FROM updateinfo_counter WHERE maintenance_db_project_id = ? #{counterType} FOR UPDATE", self.maintenance_db_project.id, *values
        ]).first
    end
    # do an atomic increase of counter
    MaintenanceIncident.escape_sql ["UPDATE updateinfo_counter SET counter = ?  WHERE maintenance_db_project_id = ? #{counterType}",counter+1, self.maintenance_db_project.id,*values]
    self.counter = r[0].to_i + 1
    self.save!
  end

  def getUpdateinfoId( id_template, patch_name=nil )
    # this is not used anymore, but we need to keep it for released incidents base on old (OBS 2.5) code
    return self.updateinfo_id if self.updateinfo_id

    # initialize on first run
    initUpdateinfoId(id_template, patch_name)

    my_id = id_template

    # replace place holders
    my_id.gsub!( /%C/, self.counter.to_s )
    my_id.gsub!( /%Y/, self.released_at.year.to_s )
    my_id.gsub!( /%M/, self.released_at.month.to_s )
    my_id.gsub!( /%D/, self.released_at.day.to_s )
    my_id.gsub!( /%N/, self.name || "" )
    my_id.gsub!( /%i/, self.incident_id.to_s )
    my_id.gsub!( /%g/, self.id.to_s )

    return my_id
  end

end
