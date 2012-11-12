require File.expand_path(File.dirname(__FILE__) + "/20121112104534_fix_projects_charset")

class FixPackagesCharset < ActiveRecord::Migration
  def up
    FixProjectsCharset.fix_double_utf8("packages", "title")
    FixProjectsCharset.fix_double_utf8("packages", "description") 
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
