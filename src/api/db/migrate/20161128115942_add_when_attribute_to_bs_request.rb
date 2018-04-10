# frozen_string_literal: true

class AddWhenAttributeToBsRequest < ActiveRecord::Migration[5.0]
  class TempBsRequest < ApplicationRecord
    self.table_name = 'bs_requests'
  end

  def self.up
    add_column :bs_requests, :updated_when, :datetime
    BsRequest.update_all('updated_when = updated_at')
  end

  def self.down
    remove_column :bs_requests, :updated_when, :datetime
  end
end
