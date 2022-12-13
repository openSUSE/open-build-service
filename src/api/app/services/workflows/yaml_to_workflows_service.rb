module Workflows
  class YAMLToWorkflowsService
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
      rescue Psych::SyntaxError => e
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

      # Mapping the placeholder variables to their values from the webhook event payload
      format(File.read(file_path),
             SCM_ORGANIZATION_NAME: scm_organization_name,
             SCM_REPOSITORY_NAME: scm_repository_name,
             # If someone uses this placeholder variable in a workflow which runs for pull request webhook events, we have a default
             # value even though this is wrong. Here, we cannot inform users about this since we're processing the whole workflows file
             SCM_PR_NUMBER: @scm_webhook.payload.fetch(:pr_number, 'NO_PR_NUMBER'),
             SCM_COMMIT_SHA: @scm_webhook.payload.fetch(:commit_sha))
    end
  end
end
