module Workflows
  class YAMLToWorkflowsService
    def initialize(yaml_file:, scm_webhook:, token:, workflow_run_id:)
      @yaml_file = yaml_file
      @scm_webhook = scm_webhook
      @token = token
      @workflow_run_id = workflow_run_id
    end

    def call
      create_workflows
    end

    private

    def create_workflows
      begin
        parsed_workflows_yaml = YAML.safe_load(File.read(@yaml_file))
      rescue Psych::SyntaxError => e
        raise Token::Errors::WorkflowsYamlNotParsable, "Unable to parse .obs/workflows.yml: #{e.message}"
      end

      parsed_workflows_yaml
        .map do |_workflow_name, workflow_instructions|
        Workflow.new(workflow_instructions: workflow_instructions, scm_webhook: @scm_webhook, token: @token,
                     workflow_run_id: @workflow_run_id)
      end
    end
  end
end
