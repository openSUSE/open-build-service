class RemoveSourceProjectIdAndSourcePackageIdFromBsRequestActions < ActiveRecord::Migration[5.1]
  def change
    # rubocop:disable Rails/ReversibleMigration
    remove_reference(:bs_request_actions, :source_package, index: true)
    remove_reference(:bs_request_actions, :source_project, index: true)
    # rubocop:enable Rails/ReversibleMigration
  end
end
