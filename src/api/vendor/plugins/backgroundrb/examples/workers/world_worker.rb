class WorldWorker < BackgrounDRb::MetaWorker
  set_worker_name :world_worker
  def create(args = nil)
    #logger.info "starting world worker"
  end

  def hello_world
    a = lambda { "Hello world" }
    return a
  end
end

