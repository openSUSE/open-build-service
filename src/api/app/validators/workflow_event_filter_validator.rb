class WorkflowEventFilterValidator < ActiveModel::Validator
  SUPPORTED_FILTER_EVENTS = ['push', 'pull_request'].freeze

  def validate(workflow)
    # FIXME: replace private method calls
    if workflow.send(:supported_filters).key?(:event)
      # The filters method is needed for the branch_matches_branches_filter that will eventually be a validator.
      workflow.errors.add(:base, "Workflow filter not supported: #{workflow.filters[:event]}") unless
        SUPPORTED_FILTER_EVENTS.include?(workflow.filters[:event])
    else
      workflow.errors.add(:base, 'Workflow filter not present')
    end

    false
  end
end
