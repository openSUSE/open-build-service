module EventObjectPackage
  extend ActiveSupport::Concern

  def event_object
    Package.unscoped.includes(:project).where(name: Package.striping_multibuild_suffix(payload['package']), projects: { name: payload['project'] })
  end
end
