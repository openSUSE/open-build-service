class CreateComments < ActiveRecord::Migration
  def change
    create_table :comments do |t|
      t.references :project
      t.references :package
      t.references :bs_request
      t.string :title
      t.text :body
      t.integer :parent_id
      t.string :type
      t.string :user

      t.timestamps
    end
    add_index :comments, :project_id
    add_index :comments, :package_id
    add_index :comments, :bs_request_id
  end
end
