# The maintenance incident class represents the entry in the database.
#
class MaintenanceIncident < ActiveRecord::Base

  belongs_to :db_project
  belongs_to :maintenance_db_project
  
end
