class RenameNameToDescriptionInTokens < ActiveRecord::Migration[6.1]
  def up
    # rename column is safe in mysql 5.6 and beyond
    # check https://stefan.magnuson.co/posts/2020-04-18-zero-downtime-migrations-with-rails-and-mysql/
    safety_assured { rename_column :tokens, :name, :description }
  end

  def down
    safety_assured { rename_column :tokens, :description, :name }
  end
end
