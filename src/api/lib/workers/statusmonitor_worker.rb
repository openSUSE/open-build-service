class StatusmonitorWorker < BackgrounDRb::MetaWorker
  set_worker_name :statusmonitor_worker

  def create(args = nil)
     @backend ||= ActiveXML::Config.transport_for :packstatus
     update_workerstatus
     add_periodic_timer(30) { update_workerstatus }
  end

  def update_workerstatus
    ret = @backend.direct_http( URI('/build/_workerstatus') )
    Rails.cache.write('workerstatus', ret)
  end

end

