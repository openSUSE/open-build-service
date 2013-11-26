class DbProjectType < ActiveRecord::Base
  validates_presence_of :name
  validates_inclusion_of :name, in: %w(standard maintenance maintenance_incident maintenance_release)
end
