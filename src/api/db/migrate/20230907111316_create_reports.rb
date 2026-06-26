class CreateReports < ActiveRecord::Migration[7.0]
  def change
    create_table :reports, id: :bigint do |t|
      t.belongs_to :user, null: false, foreign_key: true, type: :integer
      t.references :reportable, polymorphic: true, null: false, type: :integer
      t.text :reason

      t.timestamps
    end
  end
end
