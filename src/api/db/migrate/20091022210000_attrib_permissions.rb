class AttribPermissions < ActiveRecord::Migration
  def self.up
    create_table "attrib_namespace_modifiable_bies" do |t|
      t.column "attrib_namespace_id", :integer, :null => false
      t.column "bs_user_id", :integer
      t.column "bs_group_id", :integer
      t.column "bs_role_id", :integer
    end
    add_index "attrib_namespace_modifiable_bies", ["attrib_namespace_id", "bs_user_id", "bs_group_id", "bs_role_id"], :name => "attrib_namespace_user_role_all_index", :unique => true

    create_table "attrib_type_modifiable_bies" do |t|
      t.column "attrib_type_id", :integer, :null => false
      t.column "bs_user_id", :integer
      t.column "bs_group_id", :integer
      t.column "bs_role_id", :integer
    end
    add_index "attrib_type_modifiable_bies", ["attrib_type_id", "bs_user_id", "bs_group_id", "bs_role_id"], :name => "attrib_type_user_role_all_index", :unique => true
  end

  def self.down
    drop_table "attrib_namespace_modifiable_bies"
    drop_table "attrib_type_modifiable_bies"
  end
end
