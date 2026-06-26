module EventObjectProject
  extend ActiveSupport::Concern

  def event_object
    Project.unscoped.find_by(name: payload['project'])
  end
end
