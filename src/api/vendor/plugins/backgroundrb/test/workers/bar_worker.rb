class BarWorker < BackgrounDRb::MetaWorker
  set_worker_name :bar_worker
  reload_on_schedule true
  def create

  end
  def do_job

  end
end
