# frozen_string_literal: true

class SetDefaultForColorTheme < ActiveRecord::Migration[7.2]
  def up
    User.where(in_beta: false, color_theme: :system).in_batches do |batch|
      batch.find_each do |user|
        user.update_columns(color_theme: :light) # rubocop:disable Rails/SkipsModelValidations
      end
    end
    DisabledBetaFeature.where(name: 'color_themes').find_each do |disabled_beta_feature|
      disabled_beta_feature.user.update_columns(color_theme: :light) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
