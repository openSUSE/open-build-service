class RenameBsGroup < ActiveRecord::Migration
  def up
    rename_column :attrib_type_modifiable_bies, :bs_group_id, :group_id
    execute "alter table attrib_type_modifiable_bies add FOREIGN KEY (group_id) references groups (id);"
    execute "alter table attrib_namespace_modifiable_bies drop FOREIGN KEY attrib_namespace_modifiable_bies_ibfk_3;"
    rename_column :attrib_namespace_modifiable_bies, :bs_group_id, :group_id
    execute "alter table attrib_namespace_modifiable_bies add FOREIGN KEY (group_id) references groups (id);"
  end

  def down
  end
end
