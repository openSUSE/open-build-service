# frozen_string_literal: true

class AddRequestPriority < ActiveRecord::Migration[4.2]
  def self.up
    execute("alter table bs_requests add column `priority` enum('critical','important','moderate','low') DEFAULT 'moderate';")
  end

  def self.down
    remove_column :bs_requests, :priority, :integer
  end
end
