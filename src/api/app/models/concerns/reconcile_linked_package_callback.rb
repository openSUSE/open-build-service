module ReconcileLinkedPackageCallback
  extend ActiveSupport::Concern

  included do
    class_attribute :reconcile_linked_package_action, default: 'create'
    after_create :reconcile_linked_package
  end

  def reconcile_linked_package
    project = Project.find_by(name: payload['project'])
    return unless project&.maintained_by_backend?

    ReconcileLinkedPackageJob.perform_later(
      action: reconcile_linked_package_action,
      project_name: payload['project'],
      package_name: payload['package']
    )
  end
end
