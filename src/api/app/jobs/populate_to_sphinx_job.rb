class PopulateToSphinxJob < ApplicationJob
  ALLOWED_MODELS = {
    package: Package,
    project: Project
  }.freeze

  queue_as :quick

  def perform(id:, model_name:)
    model_class = ALLOWED_MODELS.fetch(model_name)
    object = model_class.find_by(id: id)
    return unless object

    ThinkingSphinx::RealTime::Callbacks::RealTimeCallbacks
      .new(model_name)
      .after_save(object)
  end
end
