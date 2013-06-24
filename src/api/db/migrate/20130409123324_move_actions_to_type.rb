
class MoveActionsToType < ActiveRecord::Migration

  def change
    rename_column :bs_request_actions, :action_type, :type
  end

end
