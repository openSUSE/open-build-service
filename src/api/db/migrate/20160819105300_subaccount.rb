# frozen_string_literal: true

class Subaccount < ActiveRecord::Migration[4.2]
  def self.up
    execute "alter table users modify column `state` enum('unconfirmed','confirmed','locked','deleted','subaccount') DEFAULT 'unconfirmed';"
    add_column :users, :owner_id, :integer
  end

  def self.down
    execute "alter table users modify column `state` enum('unconfirmed','confirmed','locked','deleted') DEFAULT 'unconfirmed';"
    remove_column :users, :owner_id
  end
end
