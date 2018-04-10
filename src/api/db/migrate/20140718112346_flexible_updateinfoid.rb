# frozen_string_literal: true

class FlexibleUpdateinfoid < ActiveRecord::Migration[4.2]
  def up
    # migration had wrong number first
    return if MaintenanceIncident.column_names.include? 'counter'

    # updateinfo_id column will become obsolete by this, but we need to keep it for backward compatibility
    add_column :maintenance_incidents, :counter, :integer
    add_column :maintenance_incidents, :released_at, :datetime
    add_column :maintenance_incidents, :name, :string

    add_column :updateinfo_counter, :name, :string

    add_column :channel_targets, :id_template, :string
    remove_column :channel_targets, :tag
  end

  def down
    remove_column :maintenance_incidents, :counter
    remove_column :maintenance_incidents, :released_at
    remove_column :maintenance_incidents, :name

    remove_column :updateinfo_counter, :name

    add_column :channel_targets, :tag, :string
    remove_column :channel_targets, :id_template
  end
end
