class UseRailsEnumsReleaseTargetsTable < ActiveRecord::Migration[5.0]
  def up
    change_table(:release_targets) do |t|
      t.column :new_trigger, :integer, limit: 2, default: nil
    end

    ReleaseTarget.triggers.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      ReleaseTarget.connection.
        execute("UPDATE release_targets SET new_trigger='#{index}' WHERE release_targets.trigger='#{ReleaseTarget.triggers.key(index)}'")
    end

    remove_column :release_targets, :trigger
    rename_column :release_targets, :new_trigger, :trigger
  end

  def down
    change_table(:release_targets) do |t|
      t.column :new_trigger, "ENUM('manual', 'allsucceeded', 'maintenance')", default: nil
    end

    ReleaseTarget.triggers.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      ReleaseTarget.connection.
        execute("UPDATE release_targets SET new_trigger='#{ReleaseTarget.triggers.key(index)}' WHERE release_targets.trigger='#{index}'")
    end

    remove_column :release_targets, :trigger
    rename_column :release_targets, :new_trigger, :trigger

    puts "WARNING: After rolling back the migration you need to remove the enum definition from the model"
  end
end
