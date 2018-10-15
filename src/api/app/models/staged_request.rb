class StagedRequest < ApplicationRecord
  belongs_to :project
  belongs_to :bs_request

  validates :project_id, :bs_request_id, presence: true
end
