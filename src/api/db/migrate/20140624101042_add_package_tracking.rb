class AddPackageTracking < ActiveRecord::Migration
  def up
    create_table :binary_releases do |t|
      t.references :repository, null: false # this destroys the entry when it gets removed
      t.integer :operation, null: false
      t.datetime :obsolete_time # set when binary gets deleted or modified later

      t.integer :release_package_id

      t.string :binary_name, null: false
      t.string :binary_epoch,                    limit: 64
      t.string :binary_version,     null: false, limit: 64
      t.string :binary_release,     null: false, limit: 64
      t.string :binary_arch,        null: false, limit: 64
      t.string :binary_disturl
      t.datetime :binary_buildtime
      t.datetime :binary_releasetime, null: false

      t.string :binary_supportstatus
      t.string :binary_maintainer
    end

    add_index :binary_releases, :binary_name
    add_index :binary_releases, [:repository_id, :binary_name], name: "ra_name_index"
    add_index :binary_releases, [:binary_name, :binary_epoch, :binary_version, :binary_release, :binary_arch], name: "exact_search_index"

    execute("alter table binary_releases modify column `operation` enum('added','removed', 'modified') DEFAULT 'added';")
    execute("alter table binary_releases add FOREIGN KEY (repository_id) references repositories(id)")
    execute("alter table binary_releases add FOREIGN KEY (release_package_id) references packages(id)")
  end

  def down
    drop_table :binary_releases
  end
end
