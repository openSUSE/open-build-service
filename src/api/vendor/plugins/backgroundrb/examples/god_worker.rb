class GodWorker < BackgrounDRb::MetaWorker
  set_worker_name :god_worker
  def create(args = nil)
    logger.info "hello world"
  end
end

