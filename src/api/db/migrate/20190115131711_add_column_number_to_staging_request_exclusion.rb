class AddColumnNumberToStagingRequestExclusion < ActiveRecord::Migration[5.2]
  def change
    add_column :staging_request_exclusions, :number, :integer
  end
end
