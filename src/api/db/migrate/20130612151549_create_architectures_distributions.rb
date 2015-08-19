class CreateArchitecturesDistributions < ActiveRecord::Migration
  def up
    create_table :architectures_distributions do |t|
      t.integer :distribution_id
      t.integer :architecture_id
    end
  end

  def down
    drop_table :architectures_distributions
  end
end
