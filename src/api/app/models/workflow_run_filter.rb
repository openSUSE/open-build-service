class WorkflowRunFilter
  attr_reader :status, :event_types, :request_action, :pr_mr, :commit

  def initialize(params)
    @status = []
    @status << 'success' if params[:success]
    @status << 'running' if params[:running]
    @status << 'fail' if params[:fail]

    @event_types = []
    @event_types << 'pull_request' if params[:pull_request]
    @event_types << 'push' if params[:push]
    @event_types << 'tag_push' if params[:tag_push]

    @request_action = []
    @request_action << params[:request_action] unless params[:request_action] == 'all'

    @pr_mr = params[:pr_mr]
    @commit = params[:commit_sha]
  end

  def to_params
    { generic_event_type: params[:generic_event_type],
      status: params[:status],
      pr_number: params[:pr_mr],
      commit_sha: params[:commit] }.compact
  end
end
