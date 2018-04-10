# frozen_string_literal: true
class RemoveOldRelationsFromComments < ActiveRecord::Migration[5.0]
  def change
    remove_reference :comments, :project, index: true, foreign_key: true
    remove_reference :comments, :package, index: true, foreign_key: true
    remove_reference :comments, :bs_request, index: true
    remove_column :comments, :type, :string
  end
end
