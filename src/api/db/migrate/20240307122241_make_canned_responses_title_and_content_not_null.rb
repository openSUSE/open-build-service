class MakeCannedResponsesTitleAndContentNotNull < ActiveRecord::Migration[7.0]
  def change
    change_column_null :canned_responses, :title, false
    change_column_null :canned_responses, :content, false
  end
end
