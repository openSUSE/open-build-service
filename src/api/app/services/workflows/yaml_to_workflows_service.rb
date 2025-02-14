module Workflows
  class YAMLToWorkflowsService
    include WorkflowPlaceholderVariablesInstrumentation # for track_placeholder_variables

    # If the order of the values in this constant change, do not forget to change the mapping of the placeholder variable values
    SUPPORTED_PLACEHOLDER_VARIABLES = %i[SCM_ORGANIZATION_NAME SCM_REPOSITORY_NAME SCM_PR_NUMBER SCM_COMMIT_SHA LABEL].freeze

    def initialize(yaml_file:, token:, workflow_run:)
      @yaml_file = yaml_file
      @token = token
      @workflow_run = workflow_run
    end

    def call
      create_workflows
    end

    private

    def create_workflows
      @workflow_run.update(workflow_configuration: File.read(@yaml_file))
      begin
        parsed_workflow_configuration = YAML.safe_load(parse_workflow_configuration(@workflow_run.workflow_configuration))
      rescue Psych::SyntaxError, Token::Errors::WorkflowsYamlFormatError => e
        raise Token::Errors::WorkflowsYamlNotParsable, "Unable to parse #{@token.workflow_configuration_path}: #{e.message}"
      end

      parsed_workflow_configuration = extract_and_set_workflow_version(parsed_workflow_configuration: parsed_workflow_configuration)
      parsed_workflow_configuration
        .map do |_workflow_name, workflow_instructions|
        Workflow.new(workflow_instructions: workflow_instructions, token: @token,
                     workflow_run: @workflow_run, workflow_version_number: @workflow_version_number)
      end
    end

    def parse_workflow_configuration(workflow_configuration)
      scm_organization_name, scm_repository_name = @workflow_run.target_repository_full_name.split('/')

      # The PR number is only present in webhook events for pull requests, so we have a default value in case someone doesn't use
      # this correctly. Here, we cannot inform users about this since we're processing the whole workflows file
      pr_number = @workflow_run.pr_number || 'NO_PR_NUMBER'

      commit_sha = @workflow_run.commit_sha
      label = @workflow_run.label

      track_placeholder_variables(workflow_configuration)

      # Mapping the placeholder variables to their values from the webhook event payload
      placeholder_variables = SUPPORTED_PLACEHOLDER_VARIABLES.zip([scm_organization_name, scm_repository_name, pr_number, commit_sha, label]).to_h
      begin
        format(workflow_configuration, placeholder_variables)
      rescue ArgumentError => e
        raise Token::Errors::WorkflowsYamlFormatError, e.message
      end
    end

    def extract_and_set_workflow_version(parsed_workflow_configuration:)
      # Receive and delete the version key from the parsed yaml, so it is not
      # confused with a workflow name. Check if the version key points to a hash
      # incase 'version' is the name of a workflow e.g. {"version"=>1.1, "version"=>{"steps"=>[{"trigger_services"...
      @workflow_version_number ||= parsed_workflow_configuration.delete('version') unless parsed_workflow_configuration['version'].is_a?(Hash)
      parsed_workflow_configuration
    end
  end
end
