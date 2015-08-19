class CreateEventSubscriptions < ActiveRecord::Migration
  def change
    create_table :event_subscriptions do |t|
      t.string :eventtype, null: false, index: true
      t.string :receive, null: false, index: true
      t.belongs_to :user, index: true
      t.belongs_to :project, index: true
      t.belongs_to :package, index: true
      t.timestamps
    end
  end
end
