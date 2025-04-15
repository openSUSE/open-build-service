class DropUserIdFromReports < ActiveRecord::Migration[7.1]
  def change
    safety_assured { remove_column :reports, :user_id, :integer }
  end
end
