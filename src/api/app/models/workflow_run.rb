class WorkflowRun < ApplicationRecord
  validates :response_url, length: { maximum: 255 }
  validates :request_headers, :status, presence: true

  belongs_to :token, class_name: 'Token::Workflow', optional: true
  paginates_per 20

  enum status: {
    running: 0,
    success: 1,
    fail: 2
  }

  def update_to_fail(message)
    update(response_body: message, status: 'fail')
  end

  def payload
    @payload ||= JSON.parse(request_payload)
  end

  def hook_action
    payload['action']
  end

  def parsed_request_headers
    request_headers.split("\n").each_with_object({}) do |h, headers|
      k, v = h.split(':')
      headers[k] = v.strip
    end
  end

  def hook_event
    parsed_request_headers['HTTP_X_GITHUB_EVENT']
  end

  def repository_name
    payload['repository']['full_name']
  end

  def repository_url
    payload['repository']['html_url']
  end

  def hook_source_name
    case hook_event
    when 'pull_request'
      "##{payload['pull_request']['number']}"
    when 'push'
      "#{payload.dig('head_commit', 'id')}"
    else
      payload['repository']['full_name']
    end
  end

  def hook_source_url
    case hook_event
    when 'pull_request'
      payload['pull_request']['url']
    when 'push'
      payload.dig('head_commit', 'url')
    else
      payload['repository']['html_url']
    end
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
