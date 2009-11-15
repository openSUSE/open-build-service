class StatusmonitorWorker < BackgrounDRb::MetaWorker
  set_worker_name :statusmonitor_worker

  def create(args = nil)
     @backend ||= ActiveXML::Config.transport_for :packstatus
     update_workerstatus
     add_periodic_timer(30) { update_workerstatus }
  end

  def update_workerstatus
    begin
       ret = backend.direct_http( URI('/build/_workerstatus') )
       mytime = Time.now.to_i
       Rails.cache.write('workerstatus', ret)
       data = REXML::Document.new(ret)
       data.root.each_element('blocked') do |e|
		line = StatusHistory.new
		line.time = mytime
		line.key = 'blocked_%s' % [ e.attributes['arch'] ]
		line.value = e.attributes['jobs']
		line.save
       end
       data.root.each_element('waiting') do |e|
                line = StatusHistory.new
                line.time = mytime
                line.key = 'waiting_%s' % [ e.attributes['arch'] ]
                line.value = e.attributes['jobs']
                line.save
       end

    rescue Timeout::Error
       @backend = nil
    end
  end

end

