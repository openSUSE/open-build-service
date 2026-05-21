class AddAnityaIgnoreToPackage < ActiveRecord::Migration[7.2]
  def change
    add_column :packages, :anitya_ignore, :boolean, null: false, default: false
  end
end
