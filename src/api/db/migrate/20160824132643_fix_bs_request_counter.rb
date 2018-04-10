# frozen_string_literal: true
class FixBsRequestCounter < ActiveRecord::Migration[4.2]
  class TempBsRequest < ApplicationRecord
    self.table_name = 'bs_requests'
  end

  class TempBsRequestCounter < ApplicationRecord
    self.table_name = 'bs_request_counter'
  end

  def change
    # BsRequestCounter is not set correctly
    # Introduced with 20160321105300_request_counter.rb
    # See https://github.com/openSUSE/open-build-service/issues/2068
    change_column_default(:bs_request_counter, :counter, 1)
    counter = TempBsRequest.reorder(:number).pluck(:number).last || 0
    TempBsRequestCounter.destroy_all
    TempBsRequestCounter.create!(counter: counter + 1)
  end
end
