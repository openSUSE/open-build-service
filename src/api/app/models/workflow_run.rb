class WorkflowRun < ApplicationRecord
  validates :response_url, length: { maximum: 255 }
  validates :request_headers, :status, presence: true

  belongs_to :token, class_name: 'Token::Workflow', optional: true
  has_many :artifacts, class_name: 'WorkflowArtifactsPerStep', dependent: :destroy

  paginates_per 20

  enum status: {
    running: 0,
    success: 1,
    fail: 2
  }

  def update_to_fail(message)
    update(response_body: message, status: 'fail')
  end
end

# == Schema Information
#
# Table name: workflow_runs
#
#  id              :integer          not null, primary key
#  request_headers :text(65535)      not null
#  request_payload :text(65535)      not null
#  response_body   :text(65535)
#  response_url    :string(255)
#  status          :integer          default("running"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  token_id        :integer          not null, indexed
#
# Indexes
#
#  index_workflow_runs_on_token_id  (token_id)
#
