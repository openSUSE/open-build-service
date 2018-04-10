# frozen_string_literal: true

class RemoveColumnQueued < ActiveRecord::Migration[5.1]
  def change
    remove_column :events, :queued, :boolean, default: false
  end
end
