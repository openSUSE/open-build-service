module Workflows
  class YAMLToWorkflowsService
    def initialize(yaml_file:, pr_number:)
      @yaml_file = yaml_file
      @pr_number = pr_number
    end

    def call
      create_workflows
    end

    private

    def create_workflows
      parsed_workflows_yaml = YAML.safe_load(File.read(@yaml_file))
      workflows = []

      parsed_workflows_yaml.each do |_workflow_name, workflow|
        workflows << Workflow.new(workflow: workflow, pr_number: @pr_number)
      end
      workflows
    end
  end
end
