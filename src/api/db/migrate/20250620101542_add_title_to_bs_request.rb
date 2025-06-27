class AddTitleToBsRequest < ActiveRecord::Migration[7.0]
  def change
    add_column :bs_requests, :title, :string, limit: 100
    BsRequest.where(title: nil) do |bs_request|
      bs_request.update(title: 'Request')
    end
  end
end
