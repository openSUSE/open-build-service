class RemoveUpstreamVersionsForAggregatesAndLinks < ActiveRecord::Migration[7.0]
  def up
    # Delete all upstream versions for packages that are currently links or aggregates
    PackageVersionUpstream.where(
      package_id: PackageKind.where(kind: %w[link aggregate]).select(:package_id)
    ).delete_all
  end

  def down
    # Nothing to do for down migration
  end
end
