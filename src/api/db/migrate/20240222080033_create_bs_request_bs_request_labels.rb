class CreateBsRequestBsRequestLabels < ActiveRecord::Migration[7.0]
  def change
    create_table :bs_request_bs_request_labels, id: :integer do |t|
      t.references :bs_request, null: false, foreign_key: true, type: :integer
      t.references :bs_request_label, null: false, foreign_key: true, type: :integer

      t.timestamps
    end
  end
end
