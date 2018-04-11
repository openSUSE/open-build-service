# frozen_string_literal: true

class CreateNotifications < ActiveRecord::Migration[5.0]
  def change
    create_table :notifications do |t|
      t.references :user
      t.references :group
      t.string :type, null: false
      t.string :event_type, null: false
      t.text :event_payload, null: false
      t.string :subscription_receiver_role, null: false
      t.boolean :delivered, default: false

      t.timestamps
    end
  end
end
