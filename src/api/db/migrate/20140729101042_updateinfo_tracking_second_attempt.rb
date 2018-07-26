class UpdateinfoTrackingSecondAttempt < ActiveRecord::Migration[4.2]
  def up
    add_column :binary_releases, :binary_updateinfo, :string, charset: 'utf8'
    add_column :binary_releases, :binary_updateinfo_version, :string
    add_index :binary_releases, :binary_updateinfo

    drop_table :updateinfos
  end

  def down
    create_table :updateinfos do |t|
      t.references :repository, null: false
      t.references :package,    null: false
      t.datetime :created_at, null: false
      t.string :identifier, null: false
    end

    add_index :updateinfos, :identifier
    add_index :updateinfos, [:repository_id, :package_id]
    execute('alter table updateinfos add FOREIGN KEY (repository_id) references repositories(id)')
    execute('alter table updateinfos add FOREIGN KEY (package_id) references packages(id)')

    remove_column :binary_releases, :binary_updateinfo
    remove_column :binary_releases, :binary_updateinfo_version
  end
end
