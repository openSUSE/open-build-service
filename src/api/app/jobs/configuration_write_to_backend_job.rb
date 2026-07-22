class ConfigurationWriteToBackendJob < ApplicationJob
  queue_as :internal

  def perform(configuration_id)
    Configuration.find(configuration_id).write_to_backend
  end
end
