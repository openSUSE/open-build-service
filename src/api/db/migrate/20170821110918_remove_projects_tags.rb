# frozen_string_literal: true
class RemoveProjectsTags < ActiveRecord::Migration[5.1]
  def change
    drop_table 'db_projects_tags', id: false, force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.references :db_project, type: :integer, index: { unique: true }, foreign_key: { to_table: :projects }
      t.references :tag, index: { unique: true }, foreign_key: true
    end
  end
end
