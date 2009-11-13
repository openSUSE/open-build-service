class RenewalWorker < BackgrounDRb::MetaWorker
  set_worker_name :renewal_worker
  def create(args = nil)

  end
  def load_policies(data = nil)
    logger.info "Loading policies done on #{data}"
    return "done"
  end
end

