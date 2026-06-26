module WorkflowPlaceholderVariablesInstrumentation
  private

  def track_placeholder_variables(workflows_file_content)
    placeholder_variables = workflows_file_content.match(/%{(SCM_.*)}/)&.captures
    # There are no placeholder variables in the workflows file
    return if placeholder_variables.blank?

    supported_placeholder_variables = placeholder_variables.select do |placeholder_variable|
      Workflows::YAMLToWorkflowsService::SUPPORTED_PLACEHOLDER_VARIABLES.include?(placeholder_variable.to_sym)
    end

    # The matches are not supported placeholder variables
    return if supported_placeholder_variables.empty?

    supported_placeholder_variables.each do |placeholder_variable|
      RabbitmqBus.send_to_bus('metrics', "workflow_placeholder_variables,name=#{placeholder_variable} count=1")
    end
  end
end
