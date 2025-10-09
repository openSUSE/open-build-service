# frozen_string_literal: true

class RemoveAnityaAttribute < ActiveRecord::Migration[7.2]
  def up
    AttribType.find_by_namespace_and_name('OBS', 'AnityaDistribution').delete
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
