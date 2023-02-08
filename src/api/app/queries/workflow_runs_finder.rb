class WorkflowRunsFinder
  EVENT_TYPE_MAPPING = {
    'pull_request' => ['pull_request', 'Merge Request Hook'],
    'push' => ['push', 'Push Hook'],
    'tag_push' => ['push', 'Tag Push Hook']
  }.freeze

  def initialize(relation = WorkflowRun.all)
    @relation = relation.order(created_at: :desc)
  end

  def all
    @relation.all
  end

  def group_by_generic_event_type
    EVENT_TYPE_MAPPING.to_h do |key, _value|
      [key, with_generic_event_type(key).count]
    end
  end

  def with_generic_event_type(generic_event_type, request_action = nil)
    query = case generic_event_type
            when 'tag_push'
              "request_headers LIKE '%: Tag Push Hook%' OR JSON_EXTRACT(request_payload, '$.ref') LIKE '%refs/tags/%'"
            when 'push'
              "request_headers LIKE '%: Push Hook%' OR JSON_EXTRACT(request_payload, '$.ref') LIKE '%refs/heads/%'"
            else
              EVENT_TYPE_MAPPING[generic_event_type].map do |event_type|
                "request_headers LIKE '%: #{event_type}%'"
              end.join(' OR ')
            end

    workflow_runs = @relation.where(query)
    if request_action && generic_event_type == 'pull_request'
      workflow_runs = workflow_runs.where("JSON_EXTRACT(request_payload, '$.action') = (?) OR JSON_EXTRACT(request_payload, '$.object_attributes.action') = (?)", request_action,
                                          request_action)
    end
    workflow_runs
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
