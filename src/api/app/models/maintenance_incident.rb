# The maintenance incident class represents the entry in the database.
#
class MaintenanceIncident < ActiveRecord::Base

  belongs_to :db_project, :class_name => "DbProject"
  belongs_to :maintenance_db_project, :class_name => "DbProject"

  attr_accessible :maintenance_db_project

  def project_name
      unless self.incident_id
        sql = ActiveRecord::Base.connection();
        r = sql.execute( "SELECT counter FROM incident_counter WHERE maintenance_db_project_id = " + self.maintenance_db_project_id.to_s + " FOR UPDATE" ).first

        if r.nil?
          # no counter exists, initialize it and select again
          sql.execute( "INSERT INTO incident_counter(maintenance_db_project_id) VALUES('" + self.maintenance_db_project_id.to_s + "')" )
          r = sql.execute( "SELECT counter FROM incident_counter WHERE maintenance_db_project_id = " + self.maintenance_db_project_id.to_s + " FOR UPDATE" ).first
        end
        # do an atomic increase of counter
        sql.execute( "UPDATE incident_counter SET counter = counter+1 WHERE maintenance_db_project_id = " + self.maintenance_db_project_id.to_s )
        self.incident_id = r[0]
      end

      name = self.maintenance_db_project.name + ":" + self.incident_id.to_s 
      return name
  end

  def getUpdateinfoId( id_template )
    unless self.updateinfo_id
      # set current time, to be used 
      myTime = Time.now.utc
      my_id = "%Y-%C"
      my_id = id_template if id_template

      # Run an atomar counter++ based on the used scheme
      if my_id =~ /%Y/
        counterType = " AND year  = " + myTime.year.to_s
        year = "'" + myTime.year.to_s + "'"
      else
        counterType = " AND ISNULL(year)"
        year = "NULL"
      end
      if my_id =~ /%M/
        counterType << " AND month = " + myTime.month.to_s
        month = "'" + myTime.month.to_s + "'"
      else
        counterType << " AND ISNULL(month)"
        month = "NULL"
      end
      if my_id =~ /%D/
        counterType << " AND day   = " + myTime.day.to_s
        day = "'" + myTime.day.to_s + "'"
      else
        counterType << " AND ISNULL(day)"
        day = "NULL"
      end
      sql = ActiveRecord::Base.connection();
      r = sql.execute( "SELECT counter FROM updateinfo_counter WHERE maintenance_db_project_id = " + self.maintenance_db_project.id.to_s + counterType + " FOR UPDATE" ).first
      if r.nil?
        # no counter exists, initialize it and select again
        sql.execute( "INSERT INTO updateinfo_counter(maintenance_db_project_id, year, month, day) VALUES('" + self.maintenance_db_project.id.to_s + "', " + year + ", " + month + ", " + day + ")" )
        r = sql.execute( "SELECT counter FROM updateinfo_counter WHERE maintenance_db_project_id = " + self.maintenance_db_project.id.to_s + counterType + " FOR UPDATE" ).first
      end
      # do an atomic increase of counter
      sql.execute( "UPDATE updateinfo_counter SET counter = counter+1 WHERE maintenance_db_project_id = " + self.maintenance_db_project.id.to_s + counterType )
      counter = self.incident_id = r[0].to_i + 1

      my_id.gsub!( /%C/, counter.to_s )
      my_id.gsub!( /%Y/, myTime.year.to_s )
      my_id.gsub!( /%M/, myTime.month.to_s )
      my_id.gsub!( /%D/, myTime.day.to_s )
      my_id.gsub!( /%i/, self.incident_id.to_s )
      my_id.gsub!( /%g/, self.id.to_s )
      self.updateinfo_id = my_id
      self.save!
    end

    return self.updateinfo_id
  end
end
