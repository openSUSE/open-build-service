require File.expand_path(File.dirname(__FILE__) + "/20121112104534_fix_projects_charset")

class FixUsernameCharset < ActiveRecord::Migration
  def up
    FixProjectsCharset.fix_double_utf8("users", "realname") 
    FixProjectsCharset.fix_double_utf8("users", "email") 
    FixProjectsCharset.fix_double_utf8("users", "adminnote") 
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
