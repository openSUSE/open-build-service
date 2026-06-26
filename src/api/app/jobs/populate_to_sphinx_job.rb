class PopulateToSphinxJob < ApplicationJob
  ALLOWED_MODELS = {
    attrib: Attrib,
    bs_request: BsRequest,
    package: Package,
    package_issue: PackageIssue,
    project: Project
  }.freeze

  queue_as :quick

  # When populating the indices asynchronously we don't have the instance at hand, so we need the id and the model name to load the instance and feed it to Thinking Sphinx.
  # Sometimes we want to trigger a Sphinx update when associated data changes, when that happens, `model name` and `reference` differ, and we need to supply both.
  def perform(id:, model_name:, reference: nil, path: [])
    model_class = ALLOWED_MODELS.fetch(model_name)
    object = model_class.find_by(id: id)
    return unless object

    ThinkingSphinx::RealTime::Callbacks::RealTimeCallbacks
      .new(reference || model_name, path)
      .after_save(object)
  end
end
