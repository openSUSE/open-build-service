class CreateJoinTableNotifiedProjects < ActiveRecord::Migration[6.0]
  def change
    create_table(:notified_projects, id: :integer) do |t|
      t.references :notification, null: false, type: :integer
      t.references :project, null: false, type: :integer, index: false
      t.datetime :created_at, null: false, precision: 6

      t.index [:notification_id, :project_id], unique: true
    end
  end
end
