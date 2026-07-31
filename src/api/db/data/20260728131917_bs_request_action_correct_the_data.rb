# frozen_string_literal: true

class BsRequestActionCorrectTheData < ActiveRecord::Migration[7.2]
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Rails/SkipsModelValidations
  def up
# 1. 'add_role'
BsRequestAction.where(type: 'add_role')
  .where(
    'source_project IS NOT NULL OR source_package IS NOT NULL OR ' \
    'source_rev IS NOT NULL OR sourceupdate IS NOT NULL OR ' \
    'target_releaseproject IS NOT NULL OR target_repository IS NOT NULL'
  ).in_batches do |relation|
    relation.update_all(
      source_project: nil,
      source_package: nil,
      source_rev: nil,
      sourceupdate: nil,
      target_releaseproject: nil,
      target_repository: nil
    )
end

# 2. 'change_devel'
BsRequestAction.where(type: 'change_devel')
  .where(
    'group_name IS NOT NULL OR person_name IS NOT NULL OR ' \
    'role IS NOT NULL OR source_rev IS NOT NULL OR ' \
    'sourceupdate IS NOT NULL OR target_releaseproject IS NOT NULL OR ' \
    'target_repository IS NOT NULL'
  ).in_batches do |relation|
    relation.update_all(
      group_name: nil,
      person_name: nil,
      role: nil,
      source_rev: nil,
      sourceupdate: nil,
      target_releaseproject: nil,
      target_repository: nil
    )
end

# 3. 'delete'
BsRequestAction.where(type: 'delete')
  .where(
    'source_project IS NOT NULL OR source_package IS NOT NULL OR ' \
    'source_rev IS NOT NULL OR sourceupdate IS NOT NULL OR ' \
    'group_name IS NOT NULL OR person_name IS NOT NULL OR ' \
    'role IS NOT NULL OR target_releaseproject IS NOT NULL'
  ).in_batches do |relation|
    relation.update_all(
      source_project: nil,
      source_package: nil,
      source_rev: nil,
      sourceupdate: nil,
      group_name: nil,
      person_name: nil,
      role: nil,
      target_releaseproject: nil
    )
end

# 4. 'maintenance_incident'
BsRequestAction.where(type: 'maintenance_incident')
  .where('group_name IS NOT NULL OR person_name IS NOT NULL OR role IS NOT NULL')
  .in_batches do |relation|
    relation.update_all(
      group_name: nil,
      person_name: nil,
      role: nil
    )
end

# 5. 'maintenance_release', 'release'
BsRequestAction.where(type: ['maintenance_release', 'release'])
  .where('group_name IS NOT NULL OR person_name IS NOT NULL OR role IS NOT NULL OR target_releaseproject IS NOT NULL')
  .in_batches do |relation|
    relation.update_all(
      group_name: nil,
      person_name: nil,
      role: nil,
      target_releaseproject: nil
    )
end

# 6. 'set_bugowner'
BsRequestAction.where(type: 'set_bugowner')
  .where(
    'source_project IS NOT NULL OR source_package IS NOT NULL OR ' \
    'source_rev IS NOT NULL OR sourceupdate IS NOT NULL OR ' \
    'role IS NOT NULL OR target_releaseproject IS NOT NULL OR ' \
    'target_repository IS NOT NULL'
  ).in_batches do |relation|
    relation.update_all(
      source_project: nil,
      source_package: nil,
      source_rev: nil,
      sourceupdate: nil,
      role: nil,
      target_releaseproject: nil,
      target_repository: nil
    )
end

# 7. 'submit'
BsRequestAction.where(type: 'submit')
  .where(
    'group_name IS NOT NULL OR person_name IS NOT NULL OR ' \
    'role IS NOT NULL OR target_releaseproject IS NOT NULL OR ' \
    'target_repository IS NOT NULL'
  ).in_batches do |relation|
    relation.update_all(
      group_name: nil,
      person_name: nil,
      role: nil,
      target_releaseproject: nil,
      target_repository: nil
    )
end
  end
  # rubocop:enable Rails/SkipsModelValidations
  # rubocop:enable Metrics/CyclomaticComplexity

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
