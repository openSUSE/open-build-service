class WorkflowRunsFinder
  EVENT_TYPE_MAPPING = {
    'pull_request' => ['pull_request', 'Merge Request Hook'],
    'push' => ['push', 'Push Hook'],
    'tag_push' => ['push', 'Tag Push Hook']
  }.freeze

  def initialize(relation = WorkflowRun.all)
    @initial_relation = relation
    @relation = relation.includes([:token]).order(created_at: :desc)
  end

  def reset
    @relation = @initial_relation

    self
  end

  def all
    @relation.all
  end

  def with_event_source_name(event_source_name, filter)
    return self if event_source_name.blank?

    hook_events_array = case filter
                        when 'commit'
                          # Both push and tag_push related events deal with commit sha.
                          (EVENT_TYPE_MAPPING['push'] + EVENT_TYPE_MAPPING['tag_push']).uniq
                        when 'pr_mr'
                          EVENT_TYPE_MAPPING['pull_request']
                        else
                          []
                        end
    @relation = @relation.where(event_source_name: event_source_name, hook_event: hook_events_array)

    self
  end

  def with_status(statuses)
    statuses = [statuses] unless statuses.is_a?(Array)
    return self if statuses.empty?

    @relation = @relation.where(status: statuses)

    self
  end

  def with_type(types)
    types = [types] unless types.is_a?(Array)
    return self if types.empty?

    @relation = @relation.where(generic_event_type: types)

    self
  end

  def with_request_action(request_actions)
    request_actions = [request_actions] unless request_actions.is_a?(Array)
    return self if request_actions.compact.empty?

    @relation = @relation.where(hook_action: request_actions)

    self
  end

  def count
    @relation.count
  end
end
