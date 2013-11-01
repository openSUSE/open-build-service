class CleanupCacheLines

  attr_accessor :event

  def initialize(event)
    self.event = event
  end

  def perform
    pl = event.payload
    if pl['package']
      CacheLine.cleanup_package(pl['project'], pl['package'])
    elsif pl['project']
      CacheLine.cleanup_project(pl['project'])
    elsif pl['request']
      CacheLine.cleanup_request(pl['id'])
    end
  end
end
