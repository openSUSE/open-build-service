class AddWhenAttributeToBsRequest < ActiveRecord::Migration[5.0]
  class TempBsRequest < ActiveRecord::Base
    self.table_name = 'bs_requests'
  end

  def self.up
    add_column :bs_requests, :updated_when, :datetime
    TempBsRequest.find_each do |bs_request|
      bs_request.updated_when = bs_request.updated_at
      bs_request.save!
    end
  end

  def self.down
    TempBsRequest.find_each do |bs_request|
      bs_request.updated_at = bs_request.updated_when || bs_request.updated_at
      bs_request.save!
    end
    remove_column :bs_requests, :updated_when, :datetime
  end
end
