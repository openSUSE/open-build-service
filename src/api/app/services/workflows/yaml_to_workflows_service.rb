module Workflows
  class YAMLToWorkflowsService
    def initialize(yaml_file:, scm_extractor_payload:)
      @yaml_file = yaml_file
      @scm_extractor_payload = scm_extractor_payload
    end

    def call
      create_workflows
    end

    private

    def create_workflows
      parsed_workflows_yaml = YAML.safe_load(File.read(@yaml_file))
      workflows = []

      parsed_workflows_yaml.each do |_workflow_name, workflow|
        workflows << Workflow.new(workflow: workflow, scm_extractor_payload: @scm_extractor_payload)
      end
      workflows
    end
  end
end
