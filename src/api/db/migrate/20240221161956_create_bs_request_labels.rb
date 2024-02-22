class CreateBsRequestLabels < ActiveRecord::Migration[7.0]
  def change
    create_table :bs_request_labels, id: :integer do |t|
      t.string :name, null: false
      t.text :description

      t.timestamps
    end
  end
end
