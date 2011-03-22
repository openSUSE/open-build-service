class AddInhibitFlag < ActiveRecord::Migration

  def self.up
    # privacy is obsolete, remove it, there was never code to handle it. Add inhibit instead.
    execute "alter table flags modify column flag enum('useforbuild','sourceaccess','binarydownload','debuginfo','build','publish','access','inhibit') not null;"
  end

  def self.down
    execute "alter table flags modify column flag enum('useforbuild','sourceaccess','binarydownload','debuginfo','build','publish','access','privacy') not null;"
  end
end
