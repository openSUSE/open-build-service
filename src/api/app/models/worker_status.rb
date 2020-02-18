class WorkerStatus
  class << self
    def hidden
      mydata = Rails.cache.read('workerstatus')
      ws = Nokogiri::XML(mydata || Backend::Api::BuildResults::Worker.status).root
      # remove information about projects which are not visible to the current user
      hidden_projects(ws)
    end

    private

    def hidden_projects(worker_status_root)
      worker_status = worker_status_root
      prjs = initialize_projects(worker_status)
      prj_names = project_names(prjs.keys)

      worker_status.css('building').each do |b|
        next if prj_names.include?(b['project'])
        hide_project_information(b)
      end
      worker_status
    end

    def hide_project_information(prj)
      ['project', 'repository', 'package'].each { |k| prj[k] = '---' }
    end

    def initialize_projects(ws)
      Hash[ws.css('building').collect { |b| [b['project'], 1] }]
    end

    def project_names(prjs)
      ProjectNamesFinder.new(prjs).call
    end
  end

  def update_workerstatus_cache
    # do not add hiding in here - this is purely for statistics
    backend_status = Backend::Api::BuildResults::Worker.status
    wdata = Nokogiri::XML(backend_status)
    @mytime = Time.now.to_i
    @squeues = Hash.new(0)

    Rails.cache.write('workerstatus', backend_status, expires_in: 3.minutes)

    StatusHistory.transaction do
      ['blocked', 'waiting'].each do |state|
        wdata.search("//#{state}").each { |e| save_value_line(e, state) }
      end
      wdata.search('partition/daemon').each { |daemon| parse_daemon_infos(daemon) }
      parse_worker_infos(wdata)
      @squeues.each_pair { |key, value| StatusHistory.create(time: @mytime, key: key, value: value) }
    end

    backend_status
  end

  private

  def add_squeue(key, value)
    @squeues[key] += value.to_i
  end

  def parse_daemon_infos(daemon)
    return unless daemon.attributes['type'].value == 'scheduler'

    queue = daemon.at_xpath('queue')
    return unless queue

    architecture_name = daemon.attributes['arch'].value

    daemon_architecture(architecture_name)

    ['high', 'next', 'med', 'low'].each do |key|
      s_key = squeue_key([key, architecture_name])
      add_squeue(s_key, queue.attributes[key].value)
    end
  end

  def squeue_key(key_parts)
    generic_key_generation(key_parts.prepend('squeue'))
  end

  def generic_key_generation(key_parts)
    key_parts.join('_')
  end

  def daemon_architecture(arch_name)
    Architecture.unavailable.find_by(name: arch_name).try(:update, available: true)
  end

  def parse_worker_infos(wdata)
    allworkers = Hash.new(0)
    workers = {}

    ['building', 'idle', 'dead', 'down', 'away'].each do |state|
      wdata.search("//#{state}").each do |e|
        worker_id = e.attributes['workerid'].value
        # building+idle worker
        next if workers.key?(worker_id)
        workers[worker_id] = 1
        key = generic_key_generation([state, e.attributes['hostarch'].value])
        allworkers[key] += 1
      end
    end

    allworkers.each { |key, value| generic_save_value_line(@mytime, key, value) }
  end

  def generic_save_value_line(status_history_timestamp, key, value)
    StatusHistory.new.tap do |line|
      line.time = status_history_timestamp
      line.key = key
      line.value = value
      line.save
    end
  end

  def save_value_line(e, prefix)
    generic_save_value_line(@mytime, "#{prefix}_#{e['arch']}", e['jobs'])
  end
end
