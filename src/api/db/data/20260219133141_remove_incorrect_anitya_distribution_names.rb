# frozen_string_literal: true

class RemoveIncorrectAnityaDistributionNames < ActiveRecord::Migration[7.2]
  def up
    Project.where.not(anitya_distribution_name: Project.values_for_anitya_distributions).in_batches do |relation|
      relation.update_all(anitya_distribution_name: nil) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
