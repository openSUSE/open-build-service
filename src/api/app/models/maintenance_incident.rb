# The maintenance incident class represents the entry in the database.
#
class MaintenanceIncident < ActiveRecord::Base

  belongs_to :db_project, :class_name => "DbProject"
  belongs_to :maintenance_db_project, :class_name => "DbProject"


  class << self
    def maxIncidentId( maintenanceProjectId )
      sql = ActiveRecord::Base.connection();
      r = sql.execute( "SELECT MAX(incident_id) FROM maintenance_incidents WHERE maintenance_db_project_id = " + maintenanceProjectId.to_s ).fetch_row
      return r[0].to_i if r[0]
      return 0
    end
  end

  def createIncidentId
    # creates a unique id per maintenance project
    id = MaintenanceIncident.maxIncidentId( self.maintenance_db_project_id )
    id = id + 1
    self.incident_id = id

    return id
  end

  def getUpdateinfoId( id_template )
    unless self.updateinfo_id
      # set current time, to be used 
      myTime = Time.now.utc
      self.day   = myTime.day
      self.month = myTime.month
      self.year  = myTime.year

      # Get a unique, but readable id
      year_counter = MaintenanceIncident.count( :conditions => ["maintenance_db_project_id = BINARY ? and year = BINARY ?", self.maintenance_db_project_id, self.year] )
      
      my_id = "%Y-%C"
      my_id = id_template if id_template
      my_id.gsub!( /%C/, year_counter.to_s )
      my_id.gsub!( /%Y/, self.year.to_s )
      my_id.gsub!( /%M/, self.month.to_s )
      my_id.gsub!( /%D/, self.day.to_s )
      my_id.gsub!( /%g/, self.id.to_s )

      self.updateinfo_id = my_id
      self.save!
    end

    return self.updateinfo_id
  end
end
