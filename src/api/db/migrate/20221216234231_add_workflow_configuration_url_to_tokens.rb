class AddWorkflowConfigurationUrlToTokens < ActiveRecord::Migration[7.0]
  def change
    add_column :tokens, :workflow_configuration_url, :string
  end
end
