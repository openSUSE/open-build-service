# frozen_string_literal: true

class BackfillStatusOnBsRequests < ActiveRecord::Migration[7.2]
  def up
    BsRequest.where(status: nil).in_batches do |batch|
      batch.find_each do |bs_request|
        bs_request.update_columns(status: bs_request.state) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end

  def down; end
end
