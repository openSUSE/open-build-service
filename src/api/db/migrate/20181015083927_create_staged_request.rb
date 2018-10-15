class CreateStagedRequest < ActiveRecord::Migration[5.2]
  def change
    # rubocop:disable Rails/CreateTableWithTimestamps
    create_table :staged_requests, id: false do |t|
      t.belongs_to :bs_request, index: true, type: :integer
      t.belongs_to :project, index: true, type: :integer
      t.index [:bs_request_id, :project_id], unique: true
    end
    # rubocop:enable Rails/CreateTableWithTimestamps
  end
end
