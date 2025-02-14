module EventObjectRepository
  extend ActiveSupport::Concern

  def event_object
    Repository.find_by_project_and_name(payload['project'], payload['repo'])
  end
end
