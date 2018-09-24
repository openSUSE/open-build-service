class UpdateStatusChecksTable < ActiveRecord::Migration[5.2]
  def change
    remove_reference :status_checks, :checkable, polymorphic: { limit: 191 }
    add_reference :status_checks, :status_reports, foreign_key: true, type: :integer
  end
end
