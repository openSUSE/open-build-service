class CleanupCacheLines

  attr_accessor :event

  def initialize(event)
    self.event = event
  end

  def cleanup(rel)
    rel.each do |r|
      Rails.cache.delete(r.key)
    end
    rel.delete_all
  end

  def cleanup_package(project, package)
    cleanup(CacheLine.where(project: project, package: package))
  end

  def cleanup_project(project)
    cleanup(CacheLine.where(project: project))
  end

  def cleanup_request(request)
    cleanup(CacheLine.where(request: request))
  end

  def perform
    pl = event.payload
    if pl['package']
      cleanup_package(pl['project'], pl['package'])
    elsif pl['project']
      cleanup_project(pl['project'])
    elsif pl['request']
      cleanup_request(pl['id'])
    end
  end
end
