class WorkflowRunsFinder
  EVENT_TYPE_MAPPING = {
    'pull_request' => 'pull_request',
    'Merge Request Hook' => 'pull_request',
    'push' => 'push',
    'Push Hook' => 'push',
    'Tag Push Hook' => 'push'
  }.freeze

  def initialize(relation = WorkflowRun.all)
    @relation = relation.order(created_at: :desc)
  end

  def all
    @relation.all
  end

  def group_by_generic_event_type
    @relation.all.each_with_object(Hash.new(0)) do |workflow_run, grouped_workflows|
      key = find_generic_event_type(workflow_run.hook_event)
      grouped_workflows[key] += 1
    end
  end

  def with_generic_event_type(generic_event_type)
    query = find_real_event_types(generic_event_type).map do |real_event_type|
      "request_headers LIKE '%#{real_event_type}%'"
    end.join(' OR ')

    @relation.where(query)
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

  private

  def find_real_event_types(generic_event_type)
    EVENT_TYPE_MAPPING.filter_map { |key, value| key if value == generic_event_type }
  end

  def find_generic_event_type(real_event_type)
    EVENT_TYPE_MAPPING[real_event_type]
  end
end
