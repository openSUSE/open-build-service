# frozen_string_literal: true
class RequestCounter < ActiveRecord::Migration[4.2]
  def self.up
    add_column :bs_requests, :number, :integer
    add_index :bs_requests, :number

    create_table :bs_request_counter do |t|
      t.integer :counter, default: 0
    end

    # migrate
    BsRequest.connection.execute('UPDATE bs_requests AS br SET br.number = br.id')

    # set counter
    lastreq = BsRequest.all.order(:id).last
    BsRequest.connection.execute "INSERT INTO bs_request_counter(counter) VALUES('#{lastreq.id}')" if lastreq
  end

  def self.down
    remove_column :bs_requests, :number
    drop_table :bs_request_counter
  end
end
