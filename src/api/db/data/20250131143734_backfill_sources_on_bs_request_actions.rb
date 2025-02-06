# frozen_string_literal: true

class BackfillSourcesOnBsRequestActions < ActiveRecord::Migration[7.0]
  # rubocop:disable Rails/SkipsModelValidations
  def up
    # Backfill source_project_id of BsRequestAction that have source_project set
    BsRequestAction.where(source_project_id: nil).where.not(source_project: nil).find_each do |action|
      action.update_columns(source_project_id: Project.find_by(name: action.source_project)&.id)
    end

    # Backfill source_package_id of BsRequestAction that have source_project and source_package and source_project_id set
    BsRequestAction.where(source_package_id: nil).where.not(source_project: nil).where.not(source_package: nil).where.not(source_project_id: nil).find_each do |action|
      action.update_columns(source_package_id: Package.find_by(name: action.source_package, project_id: action.source_project_id)&.id)
    end
  end
  # rubocop:enable Rails/SkipsModelValidations

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
