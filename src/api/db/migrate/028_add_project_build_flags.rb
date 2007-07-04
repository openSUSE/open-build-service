class AddProjectBuildFlags < ActiveRecord::Migration
  def self.up
    # === project flag groups table ===
    
    create_table "project_flag_groups", :force => true do |t|
      t.column "created_at", :timestamp
      t.column "updated_at", :timestamp
      t.column "db_project_id", :integer
      t.column "flag_group_type_id", :integer
    end

    add_index "project_flag_groups", ["db_project_id"], :name => "db_project_id_index"
    add_index "project_flag_groups", ["flag_group_type_id"], :name => "flag_group_type_id_index"

    # === package flag groups table ===
    
    create_table "package_flag_groups", :force => true do |t|
      t.column "created_at", :timestamp
      t.column "updated_at", :timestamp
      t.column "db_project_id", :integer
      t.column "flag_group_type_id", :integer
    end

    add_index "package_flag_groups", ["db_project_id"], :name => "db_project_id_index"
    add_index "package_flag_groups", ["flag_group_type_id"], :name => "flag_group_type_id_index"

    # === flag group types table ===
    
    create_table "flag_group_types", :force => true do |t|
      t.column "created_at", :timestamp
      t.column "updated_at", :timestamp
      t.column "title", :string
    end

    FlagGroupType.create :title => "useforbuild"
    FlagGroupType.create :title => "publish"
    FlagGroupType.create :title => "build"
    FlagGroupType.create :title => "debuginfo"

    # === project flags table ===
    
    create_table "project_flags", :force => true do |t|
      t.column "created_at", :timestamp
      t.column "updated_at", :timestamp
      t.column "project_flag_group_id", :integer
      t.column "flag_type_id", :integer
    end

    add_index "project_flags", ["project_flag_group_id"], :name => "project_flag_group_id_index"
    add_index "project_flags", ["flag_type_id"], :name => "flag_type_id_index"

    # === package flags table ===
    
    create_table "package_flags", :force => true do |t|
      t.column "created_at", :timestamp
      t.column "updated_at", :timestamp
      t.column "package_flag_group_id", :integer
      t.column "flag_type_id", :integer
    end

    add_index "package_flags", ["package_flag_group_id"], :name => "package_flag_group_id_index"
    add_index "package_flags", ["flag_type_id"], :name => "flag_type_id_index"

    # === flag types table ===
    
    create_table "flag_types", :force => true do |t|
      t.column "created_at", :timestamp
      t.column "updated_at", :timestamp
      t.column "title", :string
    end

    FlagType.create :title => "disable"
    FlagType.create :title => "enable"
  end

  def self.down
    drop_table "flag_group_types"
    drop_table "flag_types"
    drop_table "project_flag_groups"
    drop_table "package_flag_groups"
    drop_table "project_flags"
    drop_table "package_flags"
  end
end
