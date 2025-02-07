# frozen_string_literal: true

class NullifyTargetsOnBsRequestActions < ActiveRecord::Migration[7.0]
  # rubocop:disable Rails/SkipsModelValidations
  def up
    BsRequestAction
      .left_joins(:target_project_object)
      .where.not(bs_request_actions: { target_project_id: nil })
      .where(projects: { id: nil })
      .in_batches
      .update_all(target_project_id: nil)

    BsRequestAction
      .left_joins(:target_package_object)
      .where.not(bs_request_actions: { target_package_id: nil })
      .where(packages: { id: nil })
      .in_batches.update_all(target_package_id: nil)
  end
  # rubocop:enable Rails/SkipsModelValidations

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
