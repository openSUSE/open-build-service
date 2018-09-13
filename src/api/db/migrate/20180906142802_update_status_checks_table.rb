class UpdateStatusChecksTable < ActiveRecord::Migration[5.2]
  def change
    reversible do |dir|
      change_table :status_checks do |t|
        dir.up do
          t.remove :checkable_id
          t.remove :checkable_type
          t.belongs_to :status_reports, type: :integer, index: true
        end
        dir.down do
          t.integer :checkable_id
          t.string :checkable_type
          t.remove :status_reports
        end
      end
    end
  end
end
