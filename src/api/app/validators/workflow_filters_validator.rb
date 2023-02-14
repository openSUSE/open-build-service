class WorkflowFiltersValidator < ActiveModel::Validator
  SUPPORTED_FILTER_VALUES = [:only, :ignore].freeze
  DOCUMENTATION_LINK = "#{::Workflow::SCM_CI_DOCUMENTATION_URL}#sec.obs.obs_scm_ci_workflow_integration.setup.obs_workflows.filters".freeze

  def validate(record)
    @workflow = record
    @workflow_instructions = record.workflow_instructions

    validate_filters

    # We use the `:filter` or `:filters` key to have error messages which read better, so we check both.
    return unless @workflow.errors.include?(:filter) || @workflow.errors.include?(:filters)

    # Guide users by sharing a link whenever there's a validation error
    @workflow.errors.add(:base, "Documentation for filters: #{DOCUMENTATION_LINK}")
  end

  private

  def validate_filters
    # Filters aren't mandatory in a workflow
    return unless @workflow_instructions.key?(:filters)
    return @workflow.errors.add(:filters, 'definition is wrong') unless valid_filters_definition?

    if unsupported_filters.present?
      @workflow.errors.add(:filters,
                           "#{unsupported_filters.keys.to_sentence} are unsupported")
    end

    @workflow.errors.add(:filters, 'for branches are not supported for the tag push event') if unsupported_filters_for_event?

    return if unsupported_filter_values.blank?

    @workflow.errors.add(:filters, "#{unsupported_filter_values.to_sentence} have unsupported values, " \
                                   "#{SUPPORTED_FILTER_VALUES.map { |key| "'#{key}'" }.to_sentence} are the only supported values.")
  end

  # FIXME: Remove once we have general workflow.yml validation
  def valid_filters_definition?
    @workflow_instructions[:filters].is_a?(Hash)
  end

  def unsupported_filters
    @unsupported_filters ||= @workflow_instructions[:filters].select { |key, _value| Workflow::SUPPORTED_FILTERS.exclude?(key.to_sym) }
  end

  def unsupported_filter_values
    @unsupported_filter_values ||= begin
      unsupported_filter_values = []

      @workflow_instructions[:filters].each do |filter, value|
        if filter == :event
          @workflow.errors.add(:filter, 'event only supports a string value') unless value.is_a?(String)
        else
          unsupported_filter_values << filter unless value.keys.all? { |filter_type| SUPPORTED_FILTER_VALUES.include?(filter_type.to_sym) }
        end
      end
      unsupported_filter_values
    end
  end

  def unsupported_filters_for_event?
    # Tags do not have a reference to a branch, they are referring to a commit
    @workflow_instructions[:filters][:branches].present? && @workflow.scm_webhook.tag_push_event?
  end
end
