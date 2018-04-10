# frozen_string_literal: true

class AddMakeoriginolderOption < ActiveRecord::Migration[4.2]
  def self.up
    add_column :bs_request_actions, :makeoriginolder, :boolean, default: false
  end

  def self.down
    remove_column :bs_request_actions, :makeoriginolder
  end
end
