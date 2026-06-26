class AddWorkflowConfigurationPathToTokens < ActiveRecord::Migration[7.0]
  def change
    add_column :tokens, :workflow_configuration_path, :string, default: '.obs/workflows.yml'
  end
end
