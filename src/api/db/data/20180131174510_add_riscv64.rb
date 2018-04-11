# frozen_string_literal: true

class AddRiscv64 < ActiveRecord::Migration[5.1]
  def self.up
    Architecture.where(name: 'riscv64').first_or_create
  end

  def self.down
    Architecture.find_by_name('riscv64').destroy
  end
end
