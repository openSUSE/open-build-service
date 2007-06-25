class AddRepositories < ActiveRecord::Migration
  def self.up
    create_table :repositories do |t|
      t.column "db_project_id", :integer
      t.column "name", :string
    end

    add_index "repositories", ["db_project_id", "name"], :name => "projects_name_index", :unique => true

    create_table :path_elements do |t|
      t.column "parent_id", :integer
      t.column "repository_id", :integer
      t.column "position", :integer
    end

    add_index "path_elements", ["parent_id", "repository_id"], :name => "parent_repository_index", :unique => true
    add_index "path_elements", ["parent_id", "position"], :name => "parent_repo_pos_index", :unique => true

    create_table :architectures do |t|
      t.column "name", :string
    end

    add_index "architectures", ["name"], :name => "arch_name_index", :unique => true

    Architecture.create :name => "i586"
    Architecture.create :name => "x86_64"

    create_table :architectures_repositories, :id => false do |t|
      t.column "repository_id", :integer
      t.column "architecture_id", :integer
    end

    add_index "architectures_repositories", ["repository_id", "architecture_id"], :unique => true, :name => "arch_repo_index"
  end

  def self.down
    drop_table "repositories"
    drop_table "path_elements"
    drop_table "architectures"
    drop_table "architectures_repositories"
  end
end
