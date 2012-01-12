class IssueChangeFixedEnum < ActiveRecord::Migration
  def self.up
    execute "alter table db_package_issues modify column `change` enum('added','deleted','changed','kept');"
  end

  def self.down
  end
end
