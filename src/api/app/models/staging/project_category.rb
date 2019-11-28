class Staging::ProjectCategory < ApplicationRecord
  def self.table_name_prefix
    'staging_'
  end

  belongs_to :staging_workflow, class_name: 'Staging::Workflow'

  validates :staging_workflow, :title, :name_pattern, presence: true
  validates :title, length: { maximum: 30 }

  validates :name_pattern, format: { with: /\(\?\<nick\>/, message: "needs to have a capture group for 'nick'" }
end
