class CreateIssueAndPackageTypeTable < ActiveRecord::Migration
  def self.up
    # issues table
    create_table :issues do |t|
      t.string :name, :null => false
      t.integer :issue_tracker_id, :null => false
      t.string :long_name
      # the following comes usually from the remote tracker
      t.string :description
      t.integer :owner_id
      t.string :state         # trackers are too different for a fixed list.
      t.timestamps
    end
    add_index :issues, :long_name
    # set constraints
    execute "alter table issues add FOREIGN KEY (owner_id) references users (id);"
    execute "alter table issues add FOREIGN KEY (issue_tracker_id) references issue_trackers (id);"

    # packages may be of type patchinfo
    create_table :db_package_kinds do |t|
      t.integer :db_package_id
      t.integer :kind
    end
    execute "alter table db_package_kinds add FOREIGN KEY (db_package_id) references db_packages (id);"
    execute "alter table db_package_kinds modify column kind enum('patchinfo', 'aggregate', 'link') not null;" # others may be: product, spec, dsc, kiwi

    # db_package <> issue table
    create_table :db_package_issues do |t|
      t.integer :db_package_id, :null => false
      t.integer :issue_id, :null => false
    end
    # set constraints
    execute "alter table db_package_issues add FOREIGN KEY (db_package_id) references db_packages (id);"
    execute "alter table db_package_issues add FOREIGN KEY (issue_id) references issues (id);"
  end

  def self.down
    drop_table :db_package_issues
    drop_table :db_package_kinds
    drop_table :issues
  end
end
