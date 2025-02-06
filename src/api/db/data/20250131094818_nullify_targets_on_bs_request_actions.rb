# frozen_string_literal: true

class NullifyTargetsOnBsRequestActions < ActiveRecord::Migration[7.0]
  # rubocop:disable Rails/SkipsModelValidations
  def up
    BsRequestAction
      .joins('LEFT JOIN projects ON bs_request_actions.target_project_id = projects.id WHERE bs_request_actions.target_project_id IS NOT NULL AND projects.id IS NULL')
      .in_batches
      .update_all(target_project_id: nil)

    BsRequestAction
      .joins('LEFT JOIN packages ON bs_request_actions.target_package_id = packages.id WHERE bs_request_actions.target_package_id IS NOT NULL AND packages.id IS NULL')
      .in_batches
      .update_all(target_package_id: nil)
  end
  # rubocop:enable Rails/SkipsModelValidations

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
