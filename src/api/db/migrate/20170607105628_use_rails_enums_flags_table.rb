class UseRailsEnumsFlagsTable < ActiveRecord::Migration[5.0]
  def up
    change_table(:flags) do |t|
      t.column :new_status, :integer, limit: 2, null: false
      t.column :new_flag, :integer, limit: 2, null: false
    end

    Flag.statuses.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      Flag.connection.execute("UPDATE flags SET new_status='#{index}' WHERE status='#{Flag.statuses.key(index)}'")
    end

    Flag.flags.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      Flag.connection.execute("UPDATE flags SET new_flag='#{index}' WHERE flag='#{Flag.flags.key(index)}'")
    end

    remove_column :flags, :status
    remove_column :flags, :flag
    rename_column :flags, :new_status, :status
    rename_column :flags, :new_flag, :flag

    add_index(:flags, :flag, using: 'btree')
  end

  def down
    change_table(:flags) do |t|
      t.column :new_status, "ENUM('enable','disable')", null: false
      t.column :new_flag, "ENUM('useforbuild','sourceaccess','binarydownload','debuginfo','build','publish','access','lock')", null: false
    end

    Flag.statuses.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      Flag.connection.execute("UPDATE flags SET new_status='#{Flag.statuses.key(index)}' WHERE status='#{index}'")
    end

    Flag.flags.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      Flag.connection.execute("UPDATE flags SET new_flag='#{Flag.flags.key(index)}' WHERE flag='#{index}'")
    end

    remove_column :flags, :status
    remove_column :flags, :flag
    rename_column :flags, :new_status, :status
    rename_column :flags, :new_flag, :flag

    puts "WARNING: After rolling back the migration you need to remove the enum definition from the model"
  end
end
