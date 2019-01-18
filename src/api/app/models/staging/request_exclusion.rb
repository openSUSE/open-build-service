class Staging::RequestExclusion < ApplicationRecord
  def self.table_name_prefix
    'staging_'
  end

  belongs_to :staging_workflow, class_name: 'Staging::Workflow'
  belongs_to :bs_request

  validates :staging_workflow, :number, :description, presence: true
  validates :bs_request_id, numericality: true, uniqueness: { scope: :staging_workflow_id, message: 'is already excluded' }
  validates :description, length: { maximum: 255 }

  delegate :number, to: :bs_request, allow_nil: true
end
