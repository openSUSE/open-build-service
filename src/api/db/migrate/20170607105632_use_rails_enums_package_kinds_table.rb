class UseRailsEnumsPackageKindsTable < ActiveRecord::Migration[5.0]
  def up
    change_table(:package_kinds) do |t|
      t.column :new_kind, :integer, limit: 2, null: false
    end

    PackageKind.kinds.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      PackageKind.connection.
        execute("UPDATE package_kinds SET new_kind='#{index}' WHERE kind='#{PackageKind.kinds.key(index)}'")
    end

    remove_column :package_kinds, :kind
    rename_column :package_kinds, :new_kind, :kind
  end

  def down
    change_table(:package_kinds) do |t|
      t.column :new_kind, "ENUM('patchinfo', 'aggregate', 'link', 'channel', 'product')", null: false
    end

    PackageKind.kinds.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      PackageKind.connection.execute("UPDATE package_kinds SET new_kind='#{PackageKind.kinds.key(index)}' WHERE kind='#{index}'")
    end

    remove_column :package_kinds, :kind
    rename_column :package_kinds, :new_kind, :kind

    puts "WARNING: After rolling back the migration you need to remove the enum definition from the model"
  end
end
