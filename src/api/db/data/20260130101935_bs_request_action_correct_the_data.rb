# frozen_string_literal: true

class BsRequestActionCorrectTheData < ActiveRecord::Migration[7.2]
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Rails/SkipsModelValidations
  def up
    BsRequestAction.in_batches do |batch|
      batch.find_each do |bs_request_action|
        case bs_request_action.type
        when 'add_role'
          bs_request_action.update_columns(source_project: nil, source_package: nil, source_rev: nil, sourceupdate: nil, target_releaseproject: nil, target_repository: nil)
        when 'change_devel'
          bs_request_action.update_columns(group_name: nil, person_name: nil, role: nil, source_rev: nil, sourceupdate: nil, target_releaseproject: nil, target_repository: nil)
        when 'delete'
          bs_request_action.update_columns(source_project: nil, source_package: nil, source_rev: nil, sourceupdate: nil, group_name: nil, person_name: nil, role: nil, target_releaseproject: nil)
        when 'maintenance_incident'
          bs_request_action.update_columns(group_name: nil, person_name: nil, role: nil)
        when 'maintenance_release', 'release'
          bs_request_action.update_columns(group_name: nil, person_name: nil, role: nil, target_releaseproject: nil)
        when 'set_bugowner'
          bs_request_action.update_columns(source_project: nil, source_package: nil, source_rev: nil, sourceupdate: nil, role: nil, target_releaseproject: nil, target_repository: nil)
        when 'submit'
          bs_request_action.update_columns(group_name: nil, person_name: nil, role: nil, target_releaseproject: nil, target_repository: nil)
        end
      end
    end
  end
  # rubocop:enable Rails/SkipsModelValidations
  # rubocop:enable Metrics/CyclomaticComplexity

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
