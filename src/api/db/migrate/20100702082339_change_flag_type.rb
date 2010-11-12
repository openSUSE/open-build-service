class ChangeFlagType < ActiveRecord::Migration
  def self.flagmap
   { 'build' => 'BuildFlag', 'publish' => 'PublishFlag', 'useforbuild' => 'UseforbuildFlag',
     'binarydownload' => 'BinarydownloadFlag', 'privacy' => 'PrivacyFlag', 'access' => 'AccessFlag',
     'debuginfo' => 'DebuginfoFlag', 'sourceaccess' => 'SourceaccessFlag' }
  end

  def self.up
    execute "alter table flags add column flag enum('', '#{flagmap.keys.join("','")}');"

    flagmap.each do |flag, type|
      execute "update flags set flag='#{flag}' where type='#{type}';"
    end

    execute "alter table flags modify column flag enum('#{flagmap.keys.join("','")}') not null;"

    remove_index :flags, :column => ["db_package_id", "type"]
    remove_index :flags, :column => ["db_project_id", "type"]

    remove_column :flags, :type
   
    add_index :flags, ["db_package_id"]
    add_index :flags, ["db_project_id"]
  end

  def self.down
    add_column :flags, :type, :string
    flagmap.each do |flag, type|
      execute "update flags set type='#{type}' where flag='#{flag}';"
    end

    remove_column :flags, :flag
    add_index :flags, ["db_package_id", "type"]
    add_index :flags, ["db_project_id", "type"]

  end
end
