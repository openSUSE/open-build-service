class CreateDisabledBetaFeatures < ActiveRecord::Migration[6.1]
  def change
    create_table(:disabled_beta_features, id: :integer) do |t|
      t.string :name, null: false
      t.references :user, type: :integer, index: false

      t.timestamps

      t.index [:user_id, :name], unique: true
    end
  end
end
