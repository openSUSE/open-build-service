class AddKindToPathElement < ActiveRecord::Migration[6.0]
  def change
    add_column :path_elements, :kind, "ENUM('standard','hostsystem')"
    change_column_default :path_elements, :kind, from: nil, to: 'standard'
  end
end
