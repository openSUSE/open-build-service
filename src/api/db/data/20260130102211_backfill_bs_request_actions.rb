# frozen_string_literal: true

class BackfillBsRequestActions < ActiveRecord::Migration[7.2]
  def up
    # rubocop:disable Rails/SkipsModelValidations
    # 174818 rows
    BsRequestAction.where(source_project_id: nil).where.not(source_project: nil).in_batches do |batch|
      batch.joins('INNER JOIN projects ON projects.name = bs_request_actions.source_project')
           .update_all('bs_request_actions.source_project_id = projects.id')
    end
    # 26 rows
    BsRequestAction.where(source_package_id: nil).where.not(source_package: nil).in_batches do |batch|
      batch.joins('INNER JOIN projects ON projects.name = bs_request_actions.source_project')
           .joins('INNER JOIN packages ON packages.project_id = projects.id AND packages.name = bs_request_actions.source_package')
           .update_all('bs_request_actions.source_package_id = packages.id')
    end
    # 5154 rows
    BsRequestAction.where(target_project_id: nil).where.not(target_project: nil).in_batches do |batch|
      batch.joins('INNER JOIN projects ON projects.name = bs_request_actions.target_project')
           .update_all('bs_request_actions.target_project_id = projects.id')
    end
    # 68883 rows
    BsRequestAction.where(target_package_id: nil).where.not(target_package: nil).in_batches do |batch|
      batch.joins('INNER JOIN projects ON projects.name = bs_request_actions.target_project')
           .joins('INNER JOIN packages ON packages.project_id = projects.id AND packages.name = bs_request_actions.target_package')
           .update_all('bs_request_actions.target_package_id = packages.id')
    end
    # rubocop:enable Rails/SkipsModelValidations
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
