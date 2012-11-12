
class FixProjectsCharset < ActiveRecord::Migration
  
  def self.fix_double_utf8(table, column)
    #execute("select count(*) from #{table} where LENGTH(#{column}) != CHAR_LENGTH(#{column});")
    execute("create table temptable (select * from #{table} where LENGTH(#{column}) != CHAR_LENGTH(#{column}));")
    execute("alter table temptable modify temptable.#{column} text character set latin1;")
    execute("alter table temptable modify temptable.#{column} blob;")
    execute("alter table temptable modify temptable.#{column} text character set utf8;")
    execute("delete from temptable where LENGTH(#{column}) = CHAR_LENGTH(#{column});")
    execute("SET FOREIGN_KEY_CHECKS=0;")
    execute("replace into #{table} (select * from temptable);")
    execute("drop table temptable;")
  end

  def up
    FixProjectsCharset.fix_double_utf8("projects", "title")
    FixProjectsCharset.fix_double_utf8("projects", "description") 
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

