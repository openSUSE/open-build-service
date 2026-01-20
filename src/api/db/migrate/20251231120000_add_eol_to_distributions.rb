class AddEolToDistributions < ActiveRecord::Migration[7.0]
  def change
    add_column :distributions, :eol, :date
  end
end
