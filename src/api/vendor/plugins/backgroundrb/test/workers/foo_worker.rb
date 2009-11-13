class FooWorker < BackgrounDRb::MetaWorker
  set_worker_name :foo_worker
  reload_on_schedule :true
  def create args = nil
  end

  def barbar args
    "lol"
  end
end
