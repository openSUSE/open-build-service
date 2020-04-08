class ChangeDatetimePrecisionArInternalMetadata < ActiveRecord::Migration[6.0]
  def change
    reversible do |direction|
      direction.up do
        safety_assured { change_column :ar_internal_metadata, :created_at, :datetime, limit: 6 }
      end

      direction.down do
        change_column :ar_internal_metadata, :created_at, :datetime
      end
    end
  end
end
