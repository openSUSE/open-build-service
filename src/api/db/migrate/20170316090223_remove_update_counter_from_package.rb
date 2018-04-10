# frozen_string_literal: true

class RemoveUpdateCounterFromPackage < ActiveRecord::Migration[5.0]
  def change
    remove_column :packages, :update_counter, :integer
  end
end
