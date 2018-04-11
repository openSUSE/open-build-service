# frozen_string_literal: true

class AddVrevmodeAttribute < ActiveRecord::Migration[5.1]
  def self.up
    add_column :linked_projects, :vrevmode, :integer
    execute "alter table linked_projects modify column `vrevmode` enum('standard','unextend','extend') DEFAULT 'standard';"
  end

  def self.down
    remove_column :linked_projects, :vrevmode
  end
end
