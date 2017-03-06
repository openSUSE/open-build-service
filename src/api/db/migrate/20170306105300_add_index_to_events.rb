class AddIndexToEvents < ActiveRecord::Migration
  def self.up
    add_index :events, :mails_sent
  end

  def self.down
    remove_index :events, :mails_sent
  end
end
