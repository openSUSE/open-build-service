# frozen_string_literal: true

class NullifyTargetsOnBsRequestActions < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  # rubocop:disable Rails/SkipsModelValidations
  def up
    bs_request_actions = BsRequestAction.where('target_project_id IS NOT NULL AND target_package_id IS NULL')
    bs_request_actions.in_batches do |batch|
      batch.find_each do |action|
        target_project = Project.find_by(name: action.target_project)
        if target_project.nil?
          action.update_columns(target_project_id: nil)
        end
      end
    end

    bs_request_actions = BsRequestAction.where('target_project_id IS NOT NULL AND target_package_id IS NOT NULL')
    bs_request_actions.in_batches do |batch|
      batch.find_each do |action|
        target_project = Project.find_by(name: action.target_project)
        if target_project.nil?
          action.update_columns(target_project_id: nil, target_package_id: nil)
          next
        end

        target_package = Package.find_by_project_and_name(action.target_project, action.target_package)
        if target_package.nil?
          action.update_columns(target_package_id: nil)
        end
      end
    end
  end
  # rubocop:enable Rails/SkipsModelValidations

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
