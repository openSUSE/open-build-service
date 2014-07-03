class UpdateReleasedBinaries

  attr_accessor :event

  def initialize(event)
    self.event = event
  end

  def perform
    pl = event.payload
    repo = Repository.find_by_project_and_repo_name(pl['project'], pl['repo'])
    return unless repo
    repo.update_binary_releases(pl['payload'], event.created_at)
  end
end
