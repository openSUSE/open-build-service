# frozen_string_literal: true

class AddUpdatedAtToRole < ActiveRecord::Migration[5.0]
  def change
    add_timestamps(:roles, null: false)
  end
end
