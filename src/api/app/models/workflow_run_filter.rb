class WorkflowRunFilter
  attr_reader :status, :event_types, :request_action, :pr_mr, :commit

  STATUS_FILTER_NAMES = %i[success running fail].freeze
  EVENT_TYPE_FILTER_NAMES = %i[pull_request push tag_push].freeze

  def initialize(params)
    @status = []
    STATUS_FILTER_NAMES.each do |filter_name|
      @status << filter_name.to_s if params[filter_name]
    end

    @event_types = []
    EVENT_TYPE_FILTER_NAMES.each do |filter_name|
      @event_types << filter_name.to_s if params[filter_name]
    end

    @request_action = []
    @request_action << params[:request_action] unless params[:request_action] == 'all'

    @pr_mr = params[:pr_mr]
    @commit = params[:commit_sha]
  end
end
