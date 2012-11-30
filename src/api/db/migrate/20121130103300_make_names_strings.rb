class MakeNamesStrings < ActiveRecord::Migration
  def up
    execute("alter table packages modify name text character set utf8 COLLATE utf8_bin;")
    execute("alter table projects modify name text character set utf8 COLLATE utf8_bin;")
    execute("alter table users modify login text character set utf8 COLLATE utf8_bin;")
  end

  def down
    execute("alter table packages modify name tinyblob;")
    execute("alter table projects modify name tinyblob;")
    execute("alter table users modify login tinyblob;")
  end
end
