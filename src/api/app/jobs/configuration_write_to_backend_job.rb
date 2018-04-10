# frozen_string_literal: true

class ConfigurationWriteToBackendJob < ApplicationJob
  queue_as :quick

  def perform(configuration_id)
    Configuration.find(configuration_id).write_to_backend
  end
end
