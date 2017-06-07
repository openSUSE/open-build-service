class UseRailsEnumsBinaryReleasesTable < ActiveRecord::Migration[5.0]
  def up
    change_table(:binary_releases) do |t|
      t.column :new_operation, :integer, limit: 2, default: 0
    end

    BinaryRelease.operations.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      BinaryRelease.connection.
        execute("UPDATE binary_releases SET new_operation='#{index}' WHERE operation='#{BinaryRelease.operations.key(index)}'")
    end

    remove_column :binary_releases, :operation
    rename_column :binary_releases, :new_operation, :operation
  end

  def down
    change_table(:binary_releases) do |t|
      t.column :new_operation, "ENUM('added','removed','modified')", default: 'added'
    end

    BinaryRelease.operations.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      BinaryRelease.connection.
        execute("UPDATE binary_releases SET new_operation='#{BinaryRelease.operations.key(index)}' WHERE operation='#{index}'")
    end

    remove_column :binary_releases, :operation
    rename_column :binary_releases, :new_operation, :operation

    puts "WARNING: After rolling back the migration you need to remove the enum definition from the model"
  end
end
