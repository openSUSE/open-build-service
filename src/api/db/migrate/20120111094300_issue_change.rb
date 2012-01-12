class IssueChange < ActiveRecord::Migration
  def self.up
    execute "alter table db_package_issues add column `change` enum('added','removed','kept');"
  end

  def self.down
    remove_column :db_package_issues, :change
  end
end
