class CreateTextAttachments < ActiveRecord::Migration[7.0]
  def change
    create_table :text_attachments, id: false do |t|
      t.integer :attachable_id, null: false
      t.string :attachable_type, null: false
      t.integer :category, null: false
      t.text :content

      t.timestamps
    end

    add_index :text_attachments, %i[attachable_type attachable_id category], unique: true, name: 'index_text_attachment_on_attachables_and_category'
  end
end
