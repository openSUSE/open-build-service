class RemoveIndexTokensPackageId < ActiveRecord::Migration[7.0]
  def change
    remove_index 'tokens', 'package_id', name: 'package_id'
  end
end
