class RequestCounter < ActiveRecord::Migration
  def self.up
    add_column :bs_requests, :number, :integer
    add_index  :bs_requests, :number

    create_table :bs_request_counter do |t|
      t.integer :counter, default: 0
    end

    # migrate
    BsRequest.all.each do |r|
      r.number = r.id
      r.save!
    end

    # set counter
    lastreq = BsRequest.all.order(:id).last
    if lastreq
      BsRequest.connection.execute "INSERT INTO bs_request_counter(counter) VALUES('#{lastreq.id.to_s}')"
    end
  end

  def self.down
    remove_column :bs_requests, :number
    drop_table :bs_request_counter
  end
end
