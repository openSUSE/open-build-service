class AddGroupRequestsId < ActiveRecord::Migration[4.2]
  def self.up
    sql = 'alter table group_request_requests add id int(11) NOT NULL PRIMARY KEY AUTO_INCREMENT'
    ActiveRecord::Base.connection.execute(sql)
  end

  def self.down
    remove_column :group_request_requests, :id
  end
end
