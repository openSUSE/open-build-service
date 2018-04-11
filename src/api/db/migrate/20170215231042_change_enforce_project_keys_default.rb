# frozen_string_literal: true

class ChangeEnforceProjectKeysDefault < ActiveRecord::Migration[5.0]
  # has no practical effect since the entry gets set via app/model/configuration.rb on deployment
  def self.up
    change_column :configurations, :enforce_project_keys, :boolean, default: false
  end

  def self.down
    change_column :configurations, :enforce_project_keys, :boolean, default: true
  end
end
