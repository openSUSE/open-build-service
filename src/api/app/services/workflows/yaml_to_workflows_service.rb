module Workflows
  class YAMLToWorkflowsService
    include WorkflowPlaceholderVariablesInstrumentation # for track_placeholder_variables

    # If the order of the values in this constant change, do not forget to change the mapping of the placeholder variable values
    SUPPORTED_PLACEHOLDER_VARIABLES = [:SCM_ORGANIZATION_NAME, :SCM_REPOSITORY_NAME, :SCM_PR_NUMBER, :SCM_COMMIT_SHA].freeze

    def initialize(yaml_file:, scm_webhook:, token:, workflow_run:)
      @yaml_file = yaml_file
      @scm_webhook = scm_webhook
      @token = token
      @workflow_run = workflow_run
    end

    def call
      create_workflows
    end

    private

    def create_workflows
      begin
        parsed_workflows_yaml = YAML.safe_load(parse_workflows_file(@yaml_file))
      rescue Psych::SyntaxError, Token::Errors::WorkflowsYamlFormatError => e
        raise Token::Errors::WorkflowsYamlNotParsable, "Unable to parse #{@token.workflow_configuration_path}: #{e.message}"
      end

      parsed_workflows_yaml
        .map do |_workflow_name, workflow_instructions|
        Workflow.new(workflow_instructions: workflow_instructions, scm_webhook: @scm_webhook, token: @token,
                     workflow_run: @workflow_run)
      end
    end

    def parse_workflows_file(file_path)
      target_repository_full_name = @scm_webhook.payload.values_at(:target_repository_full_name, :path_with_namespace).compact.first
      scm_organization_name, scm_repository_name = target_repository_full_name.split('/')

      # The PR number is only present in webhook events for pull requests, so we have a default value in case someone doesn't use
      # this correctly. Here, we cannot inform users about this since we're processing the whole workflows file
      pr_number = @scm_webhook.payload.fetch(:pr_number, 'NO_PR_NUMBER')

      commit_sha = @scm_webhook.payload.fetch(:commit_sha)

      workflows_file_content = File.read(file_path)
      track_placeholder_variables(workflows_file_content)

      # Mapping the placeholder variables to their values from the webhook event payload
      placeholder_variables = SUPPORTED_PLACEHOLDER_VARIABLES.zip([scm_organization_name, scm_repository_name, pr_number, commit_sha]).to_h
      begin
        format(workflows_file_content, placeholder_variables)
      rescue ArgumentError => e
        raise Token::Errors::WorkflowsYamlFormatError, e.message
      end
    end
  end
end
