class AddStagingManagersGroup < ActiveRecord::Migration[5.2]
  def change
    change_table :staging_workflows do |t|
      t.references :managers_group, index: true, type: :integer
    end
  end
end
