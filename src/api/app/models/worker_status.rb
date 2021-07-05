class WorkerStatus
  WORKER_STATUS = ['building', 'idle', 'dead', 'down', 'away'].freeze

  class << self
    def hidden
      mydata = Rails.cache.fetch('workerstatus') { Backend::Api::BuildResults::Worker.status }
      ws = Nokogiri::XML(mydata).root
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
      ws.css('building').collect { |b| [b['project'], 1] }.to_h
    end

    def project_names(prjs)
      ProjectNamesFinder.new(prjs).call
    end
  end

  def save
    @workerstatus = Nokogiri::XML(Rails.cache.read('workerstatus')).root
    return unless @workerstatus

    @mytime = Time.now.to_i
    @squeues = Hash.new(0)

    StatusHistory.transaction do
      ['blocked', 'waiting'].each do |state|
        @workerstatus.search("//#{state}").each { |e| save_value_line(e, state) }
      end
      @workerstatus.search('partition/daemon').each { |daemon| parse_daemon_infos(daemon) }
      parse_worker_infos(@workerstatus)
      @squeues.each_pair { |key, value| StatusHistory.create(time: @mytime, key: key, value: value) }
    end
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
    allworkers = {}
    workers = {}

    WORKER_STATUS.each do |state|
      wdata.search("//#{state}").each do |e|
        worker_id = e.attributes['workerid'].value
        # building+idle worker
        next if workers.key?(worker_id)

        workers[worker_id] = 1
        hostarch = e.attributes['hostarch'].value
        WORKER_STATUS.each { |local_state| allworkers["#{local_state}_#{hostarch}"] ||= 0 }
        key = generic_key_generation([state, hostarch])
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
