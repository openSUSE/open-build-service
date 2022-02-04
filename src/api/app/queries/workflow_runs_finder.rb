class WorkflowRunsFinder
  def initialize(relation = WorkflowRun.all)
    @relation = relation.order(created_at: :desc)
  end

  def all
    @relation.all
  end

  def group_by_event_type
    @relation.all.each_with_object(Hash.new(0)) do |workflow_run, grouped_workflows|
      grouped_workflows[workflow_run.hook_event] += 1
    end
  end

  def with_event_type(event_type)
    allowed_events = ScmWebhookEventValidator::ALLOWED_GITHUB_EVENTS + ScmWebhookEventValidator::ALLOWED_GITLAB_EVENTS
    filtered_event_type = '%' + ([event_type] & allowed_events).first + '%'
    @relation.where('request_headers LIKE ?', filtered_event_type)
  end

  def with_status(status)
    @relation.where(status: status)
  end

  def succeeded
    with_status('success')
  end

  def running
    with_status('running')
  end

  def failed
    with_status('fail')
  end
end
