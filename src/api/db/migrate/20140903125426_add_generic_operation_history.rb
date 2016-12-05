class AddGenericOperationHistory < ActiveRecord::Migration
  def self.up
    create_table :history_elements do |t|
      t.string :type, null: false
      t.integer :op_object_id, null: false # id of request/project/...
      t.datetime :created_at, null: false
      t.references :user, null: false
      t.string :description_extension # by code
      t.text :comment # by user
    end

    add_index :history_elements, :created_at
    add_index :history_elements, :type
    add_index :history_elements, :op_object_id
  end

  def down
    drop_table :history_elements
  end
end
