class WorkerStatus
  def self.hidden
    mydata = Rails.cache.read('workerstatus')
    ws = ActiveXML::Node.new(mydata || Backend::Api::BuildResults::Worker.status)
    prjs = {}
    ws.each('building') do |b|
      prjs[b.value(:project)] = 1
    end
    names = {}
    # now try to find those we have a match for (the rest are hidden from you
    Project.where(name: prjs.keys).pluck(:name).each do |n|
      names[n] = 1
    end
    ws.each('building') do |b|
      # no prj -> we are not allowed
      unless names.has_key? b.value(:project)
        Rails.logger.debug "workerstatus2clean: hiding #{b.value(:project)} for user #{User.current.login}"
        b.set_attribute('project', '---')
        b.set_attribute('repository', '---')
        b.set_attribute('package', '---')
      end
    end
    ws
  end

  def update_workerstatus_cache
    # do not add hiding in here - this is purely for statistics
    ret = Backend::Api::BuildResults::Worker.status
    wdata = Xmlhash.parse(ret)
    @mytime = Time.now.to_i
    @squeues = {}
    Rails.cache.write('workerstatus', ret, expires_in: 3.minutes)
    StatusHistory.transaction do
      wdata.elements('blocked') do |e|
        save_value_line(e, 'blocked')
      end
      wdata.elements('waiting') do |e|
        save_value_line(e, 'waiting')
      end
      wdata.elements('partition') do |p|
        p.elements('daemon') do |daemon|
          parse_daemon_infos(daemon)
        end
      end
      parse_worker_infos(wdata)
      @squeues.each_pair do |key, value|
        StatusHistory.create time: @mytime, key: key, value: value
      end
    end
    ret
  end

  private

  def add_squeue(key, value)
    @squeues[key] ||= 0
    @squeues[key] += value.to_i
  end

  def parse_daemon_infos(daemon)
    return unless daemon['type'] == 'scheduler'
    arch = daemon['arch']
    # FIXME2.5: The current architecture model is a gross hack, not connected at all
    #           to the backend config.
    a = Architecture.find_by_name(arch)
    if a
      a.available = true
      a.save
    end
    queue = daemon.get('queue')
    return unless queue
    %w(high next med low).each { |key| add_squeue("squeue_#{key}_#{arch}", queue[key]) }
  end

  def parse_worker_infos(wdata)
    allworkers = {}
    workers = {}
    %w(building idle dead down away).each do |state|
      wdata.elements(state) do |e|
        id = e['workerid']
        if workers.has_key? id
          Rails.logger.debug 'building+idle worker'
          next
        end
        workers[id] = 1
        key = state + '_' + e['hostarch']
        allworkers["building_#{e['hostarch']}"] ||= 0
        allworkers["idle_#{e['hostarch']}"] ||= 0
        allworkers["dead_#{e['hostarch']}"] ||= 0
        allworkers["down_#{e['hostarch']}"] ||= 0
        allworkers["away_#{e['hostarch']}"] ||= 0
        allworkers[key] = allworkers[key] + 1
      end
    end

    allworkers.each do |key, value|
      line = StatusHistory.new
      line.time = @mytime
      line.key = key
      line.value = value
      line.save
    end
  end

  def save_value_line(e, prefix)
    line = StatusHistory.new
    line.time = @mytime
    line.key = "#{prefix}_#{e['arch']}"
    line.value = e['jobs']
    line.save
  end
end
