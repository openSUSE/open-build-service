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
  end

  private

  def send_worker_metrics
    states = ['dead', 'down', 'away', 'idle', 'building']
    @architecture_names.each do |architecture_name|
      states.each do |state|
        state_elements = @workerstatus.xpath("//#{state}[@hostarch=\"#{architecture_name}\"]")
        RabbitmqBus.send_to_bus('metrics', "worker,arch=#{architecture_name},state=#{state} value=#{state_elements.count}") if state_elements.any?
      end
    end
  end

  def send_job_metrics
    @architecture_names.each do |architecture_name|
      waiting = @workerstatus.xpath("//waiting[@arch=\"#{architecture_name}\"]")
      RabbitmqBus.send_to_bus('metrics', "jobs,arch=#{architecture_name},state=waiting value=#{waiting.last.attributes['jobs'].value}") if waiting.any?

      blocked = @workerstatus.xpath("//blocked[@arch=\"#{architecture_name}\"]")
      RabbitmqBus.send_to_bus('metrics', "jobs,arch=#{architecture_name},state=blocked value=#{blocked.last.attributes['jobs'].value}") if blocked.any?

      building = @workerstatus.xpath("//building[@arch=\"#{architecture_name}\"]")
      RabbitmqBus.send_to_bus('metrics', "jobs,arch=#{architecture_name},state=building value=#{building.count}") if building.any?
    end
  end

  def send_scheduler_metrics
    queues = ['high', 'med', 'low', 'next']
    @workerstatus.xpath('//partition//queue').each do |scheduler|
      partition = scheduler.parent.parent.values.first || 'main'
      architecture = scheduler.parent.attributes['arch'].value
      queues.each do |queue|
        value = scheduler.attribute(queue).value.to_i
        RabbitmqBus.send_to_bus('metrics', "scheduler,arch=#{architecture},partition=#{partition},queue=#{queue} value=#{value}") if value.positive?
      end
    end
  end
end
