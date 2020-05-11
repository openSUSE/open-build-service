class RemoveDuplicatedFlags < ActiveRecord::Migration[5.2]
  def up
    attributes = [:flag, :repo, :architecture_id, :package_id, :project_id]
    # whenever 2 flags are for the same 'thing' (in _meta), we remove all but one
    last_flags = Flag.group([:status] + attributes).select('MAX(id) as id')
    # we need to pluck the ids (even though it's a lot) as you can't delete
    # from within group queries
    Flag.where.not(id: last_flags).in_batches do |batch|
      Flag.where(id: batch.pluck(:id)).delete_all
    end

    # now comes the ugly part - we need to delete conflicting flags. If both
    # 'enable' and 'disable' are set, the backend prefers disable - so we can
    # safely remove the 'enable' for those where we have 2
    Flag.group(attributes).select(attributes).having('count(id) > 1').each do |f|
      Flag.where(flag: f.flag, repo: f.repo, architecture_id: f.architecture_id,
                 package_id: f.package_id, project_id: f.project_id, status: 'enable').delete_all
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
