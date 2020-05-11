class CreateStatusReports < ActiveRecord::Migration[5.2]
  def change
    create_table :status_reports, id: :integer, options: 'ROW_FORMAT=DYNAMIC' do |t|
      t.string :uuid
      t.belongs_to :checkable, polymorphic: { limit: 191 }, type: :integer

      t.timestamps
    end

    drop_table :status_repository_publishes, id: :integer, options: 'ROW_FORMAT=DYNAMIC' do |t|
      t.string :build_id
      t.belongs_to :repository, type: :integer, index: true
      t.timestamps
    end
  end
end
