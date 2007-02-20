class AddSeverityToStatusMessages < ActiveRecord::Migration


  def self.up
    add_column :status_messages, :severity, :integer
  end


  def self.down
    remove_column :status_messages, :severity
  end


end
