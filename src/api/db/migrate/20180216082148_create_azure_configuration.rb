# frozen_string_literal: true

class CreateAzureConfiguration < ActiveRecord::Migration[5.1]
  def change
    create_table :cloud_azure_configurations, id: :integer do |t|
      t.belongs_to :user, index: true, type: :integer
      t.text :application_id, null: true, default: nil
      t.text :application_key, null: true, default: nil
      t.timestamps
    end
  end
end
