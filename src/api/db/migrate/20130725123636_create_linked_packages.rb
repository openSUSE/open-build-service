class CreateLinkedPackages < ActiveRecord::Migration
  def change
    create_table :linked_packages, id: false do |t|
      t.belongs_to :links_to, null: false
      t.belongs_to :package, null: false
      t.integer :event, null: false
      t.datetime :updated_at
      t.primary_key :package_id
    end
  end
end
