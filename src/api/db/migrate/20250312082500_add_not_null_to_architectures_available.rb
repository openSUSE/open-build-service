class AddNotNullToArchitecturesAvailable < ActiveRecord::Migration[7.0]
  def change
    change_column_null :architectures, :available, false
  end
end
