class AddTokensPackageIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :tokens, %w[package_id], name: :index_tokens_package_id, unique: true
  end
end
