# The maintenance incident class represents the entry in the database.
#
class MaintenanceIncident < ActiveRecord::Base

  belongs_to :db_project, :class_name => "DbProject"
  belongs_to :maintenance_db_project, :class_name => "DbProject"
  
end
