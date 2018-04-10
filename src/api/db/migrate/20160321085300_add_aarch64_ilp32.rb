# frozen_string_literal: true

class AddAarch64Ilp32 < ActiveRecord::Migration[4.2]
  def self.up
    Architecture.where(name: 'aarch64_ilp32').first_or_create
  end

  def self.down
    Architecture.find_by_name('aarch64_ilp32').destroy
  end
end
