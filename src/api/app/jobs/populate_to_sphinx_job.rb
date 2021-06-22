class PopulateToSphinxJob < ApplicationJob
  ALLOWED_MODELS = {
    attrib: Attrib,
    package: Package,
    project: Project
  }.freeze

  queue_as :quick

  def perform(id:, object_to_index:, reference: nil, path: [])
    model_class = ALLOWED_MODELS.fetch(object_to_index)
    object = model_class.find_by(id: id)
    return unless object

    ThinkingSphinx::RealTime::Callbacks::RealTimeCallbacks
      .new(reference || object_to_index, path)
      .after_save(object)
  end
end
