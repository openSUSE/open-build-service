# frozen_string_literal: true

class RemoveLockVersionFromEvents < ActiveRecord::Migration[5.1]
  def change
    remove_column :events, :lock_version, :integer, default: 0, null: false
  end
end
