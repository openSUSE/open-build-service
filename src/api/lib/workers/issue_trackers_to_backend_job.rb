class IssueTrackersToBackendJob

  def initialize
  end

  def perform
    IssueTracker.write_to_backend()
  end

end


