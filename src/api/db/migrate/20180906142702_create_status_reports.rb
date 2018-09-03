class CreateStatusReports < ActiveRecord::Migration[5.2]
  def change
    create_table :status_reports, id: :integer, options: 'ROW_FORMAT=DYNAMIC' do |t|
      t.string :uuid
      t.string :uuid_type
      t.integer :checkable_id
      t.string :checkable_type

      t.timestamps
    end

    drop_table :status_repository_publishes, id: :integer, options: 'ROW_FORMAT=DYNAMIC' do |t|
      t.string :build_id
      t.belongs_to :repository, type: :integer, index: true
      t.timestamps
    end
  end
end
