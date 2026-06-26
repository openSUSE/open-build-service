class CreateDefaultPreferencesForKiwiImages < ActiveRecord::Migration[5.1]
  def up
    images = Kiwi::Image.includes(:preferences).where(kiwi_preferences: { id: nil })

    images.each(&:create_preference)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
