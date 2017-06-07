class UseRailsEnumsRepositoryTable < ActiveRecord::Migration[5.0]
  def up
    change_table(:repositories) do |t|
      t.column :new_rebuild, :integer, limit: 2, default: nil
      t.column :new_block, :integer, limit: 2, default: nil
      t.column :new_linkedbuild, :integer, limit: 2, default: nil
    end

    Repository.rebuilds.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      Repository.connection.execute("UPDATE repositories SET new_rebuild='#{index}' WHERE rebuild='#{Repository.rebuilds.key(index)}'")
      Repository.connection.execute("UPDATE repositories SET new_block='#{index}' WHERE block='#{Repository.blocks.key(index)}'")
      Repository.connection.execute("UPDATE repositories SET new_linkedbuild='#{index}' WHERE linkedbuild='#{Repository.linkedbuilds.key(index)}'")
    end

    remove_column :repositories, :rebuild
    remove_column :repositories, :block
    remove_column :repositories, :linkedbuild

    rename_column :repositories, :new_rebuild, :rebuild
    rename_column :repositories, :new_block, :block
    rename_column :repositories, :new_linkedbuild, :linkedbuild
  end

  def down
    change_table(:repositories) do |t|
      t.column :new_rebuild, "ENUM('transitive', 'direct', 'local')", default: nil
      t.column :new_block, "ENUM('all', 'local', 'never')", default: nil
      t.column :new_linkedbuild, "ENUM('off', 'localdep', 'all')", default: nil
    end

    Repository.rebuilds.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      Repository.connection.execute("UPDATE repositories SET new_rebuild='#{Repository.rebuilds.key(index)}' WHERE rebuild='#{index}'")
      Repository.connection.execute("UPDATE repositories SET new_block='#{Repository.blocks.key(index)}' WHERE block='#{index}'")
      Repository.connection.execute("UPDATE repositories SET new_linkedbuild='#{Repository.linkedbuilds.key(index)}' WHERE linkedbuild='#{index}'")
    end

    remove_column :repositories, :rebuild
    remove_column :repositories, :block
    remove_column :repositories, :linkedbuild

    rename_column :repositories, :new_rebuild, :rebuild
    rename_column :repositories, :new_block, :block
    rename_column :repositories, :new_linkedbuild, :linkedbuild

    puts "WARNING: After rolling back the migration you need to remove the enum definition from the model"
  end
end
