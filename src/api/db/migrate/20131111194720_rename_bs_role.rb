class RenameBsRole < ActiveRecord::Migration
  def up
    rename_column :attrib_type_modifiable_bies, :bs_role_id, :role_id
    execute "alter table attrib_type_modifiable_bies add FOREIGN KEY (role_id) references roles (id);"
  end

  def down
  end
end
