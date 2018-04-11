# frozen_string_literal: true

class AddReleasename < ActiveRecord::Migration[4.2]
  def self.up
    add_column :packages, :releasename, :string
  end

  def self.down
    remove_column :packages, :releasename
  end
end
