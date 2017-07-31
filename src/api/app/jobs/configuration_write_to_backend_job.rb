class ConfigurationWriteToBackendJob < ApplicationJob
  def perform(configuration_id)
    Configuration.find(configuration_id).write_to_backend
  end
end
