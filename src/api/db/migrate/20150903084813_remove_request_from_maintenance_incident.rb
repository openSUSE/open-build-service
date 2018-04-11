# frozen_string_literal: true

class RemoveRequestFromMaintenanceIncident < ActiveRecord::Migration[4.2]
  def self.up
    remove_column :maintenance_incidents, :request
  end

  def self.down
    add_column :maintenance_incidents, :request, :integer
  end
end
