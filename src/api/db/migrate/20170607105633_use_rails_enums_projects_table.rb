class UseRailsEnumsProjectsTable < ActiveRecord::Migration[5.0]
  def up
    change_table(:projects) do |t|
      t.column :new_kind, :integer, limit: 2, default: 0
    end

    Project.kinds.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      Project.connection.execute("UPDATE projects SET new_kind='#{index}' WHERE kind='#{Project.kinds.key(index)}'")
    end

    remove_column :projects, :kind
    rename_column :projects, :new_kind, :kind
  end

  def down
    change_table(:projects) do |t|
      t.column :new_kind, "ENUM('standard', 'maintenance', 'maintenance_incident', 'maintenance_release')", default: 'standard'
    end

    Project.kinds.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      Project.connection.execute("UPDATE projects SET new_kind='#{Project.kinds.key(index)}' WHERE kind='#{index}'")
    end

    remove_column :projects, :kind
    rename_column :projects, :new_kind, :kind

    puts "WARNING: After rolling back the migration you need to remove the enum definition from the model"
  end
end
