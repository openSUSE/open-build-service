class RemoveBsPrefix < ActiveRecord::Migration
  def up
    execute( "alter table watched_projects drop FOREIGN KEY watched_projects_ibfk_1;" )
    rename_column :watched_projects, :bs_user_id, :user_id
    execute "alter table watched_projects add FOREIGN KEY (user_id) references users (id);"
    execute "alter table attrib_namespace_modifiable_bies drop FOREIGN KEY attrib_namespace_modifiable_bies_ibfk_2"
    remove_index :attrib_namespace_modifiable_bies, :bs_user_id
    rename_column :attrib_namespace_modifiable_bies, :bs_user_id, :user_id
    execute "alter table attrib_namespace_modifiable_bies add FOREIGN KEY (user_id) references users (id);"
    add_index :attrib_namespace_modifiable_bies, :user_id
    rename_column :attrib_type_modifiable_bies, :bs_user_id, :user_id
    execute "alter table attrib_type_modifiable_bies add FOREIGN KEY (user_id) references users (id);"
  end

  def down
  end
end
