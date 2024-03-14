class WorkerMeasurementsJob < ApplicationJob
  queue_as :quick

  def perform
    return unless CONFIG['amqp_options']

    @workerstatus = Nokogiri::XML(Rails.cache.read('workerstatus')).root
    return unless @workerstatus

    @architecture_names = Architecture.available.pluck(:name)

    send_worker_metrics
    send_job_metrics
    send_scheduler_metrics
    send_daemon_metrics
  end

  private

  def send_worker_metrics
    states = %w[dead down away idle building]
    @architecture_names.each do |architecture_name|
      states.each do |state|
        state_elements = @workerstatus.xpath("//#{state}[@hostarch=\"#{architecture_name}\"]")
        if state_elements.any?
          RabbitmqBus.send_to_bus('metrics',
                                  "worker,arch=#{architecture_name},state=#{state} value=#{state_elements.count}")
        end
      end
    end
  end

  def send_job_metrics
    @architecture_names.each do |architecture_name|
      waiting = @workerstatus.xpath("//waiting[@arch=\"#{architecture_name}\"]")
      if waiting.any?
        RabbitmqBus.send_to_bus('metrics',
                                "jobs,arch=#{architecture_name},state=waiting value=#{waiting.last.attributes['jobs'].value}")
      end

      blocked = @workerstatus.xpath("//blocked[@arch=\"#{architecture_name}\"]")
      if blocked.any?
        RabbitmqBus.send_to_bus('metrics',
                                "jobs,arch=#{architecture_name},state=blocked value=#{blocked.last.attributes['jobs'].value}")
      end

      building = @workerstatus.xpath("//building[@arch=\"#{architecture_name}\"]")
      if building.any?
        RabbitmqBus.send_to_bus('metrics',
                                "jobs,arch=#{architecture_name},state=building value=#{building.count}")
      end
    end
  end

  def send_scheduler_metrics
    queues = %w[high med low next]
    @workerstatus.xpath('//partition//queue').each do |scheduler|
      partition = scheduler.parent.parent.values.first || 'main'
      architecture = scheduler.parent.attributes['arch'].value
      queues.each do |queue|
        value = scheduler.attribute(queue).value.to_i
        if value.positive?
          RabbitmqBus.send_to_bus('metrics',
                                  "scheduler,arch=#{architecture},partition=#{partition},queue=#{queue} value=#{value}")
        end
      end
    end
  end

  def send_daemon_metrics
    @workerstatus.xpath('//partition/daemon').each do |daemon|
      partition = daemon.parent.values.first || 'main'
      type = daemon.attributes['type'].value
      state = daemon.attributes['state'].value
      arch = daemon.attributes['arch']
      arch = (arch.nil? ? '' : ",arch=#{arch.value}")
      RabbitmqBus.send_to_bus('metrics',
                              "backend_daemon_status,partition=#{partition},type=#{type},state=#{state}#{arch} count=1")
    end
  end
end
