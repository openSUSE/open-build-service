# frozen_string_literal: true

class AddK1om < ActiveRecord::Migration[4.2]
  def self.up
    Architecture.where(name: 'k1om').first_or_create
  end

  def self.down
    Architecture.find_by_name('k1om').destroy
  end
end
