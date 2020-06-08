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

# == Schema Information
#
# Table name: staging_request_exclusions
#
#  id                  :integer          not null, primary key
#  description         :string(255)
#  number              :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  bs_request_id       :integer          not null, indexed
#  staging_workflow_id :integer          not null, indexed
#
# Indexes
#
#  index_staging_request_exclusions_on_bs_request_id        (bs_request_id)
#  index_staging_request_exclusions_on_staging_workflow_id  (staging_workflow_id)
#
