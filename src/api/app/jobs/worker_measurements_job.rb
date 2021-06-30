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
    @architecture_names.each do |architecture_name|
      dead_state = @workerstatus.xpath("//dead[@hostarch=\"#{architecture_name}\"]").count
      down_state = @workerstatus.xpath("//down[@hostarch=\"#{architecture_name}\"]").count
      away_state = @workerstatus.xpath("//away[@hostarch=\"#{architecture_name}\"]").count
      idle_state = @workerstatus.xpath("//idle[@hostarch=\"#{architecture_name}\"]").count
      building_state = @workerstatus.xpath("//building[@hostarch=\"#{architecture_name}\"]").count

      RabbitmqBus.send_to_bus('metrics', "worker,arch=#{architecture_name} dead=#{dead_state} down=#{down_state} away=#{away_state} idle=#{idle_state} building=#{building_state}")
    end
  end

  def send_job_metrics
    @architecture_names.each do |architecture_name|
      waiting = @workerstatus.xpath("//waiting[@arch=\"#{architecture_name}\"]")
      waiting = waiting.any? ? waiting.last.attributes['jobs'].value : 0
      blocked = @workerstatus.xpath("//blocked[@arch=\"#{architecture_name}\"]")
      blocked = blocked.any? ? blocked.last.attributes['jobs'].value : 0
      RabbitmqBus.send_to_bus('metrics', "jobs,arch=#{architecture_name},state=waiting count=#{waiting}")
      RabbitmqBus.send_to_bus('metrics', "jobs,arch=#{architecture_name},state=blocked count=#{blocked}")
    end

    @workerstatus.search('//building').each do |job|
      hostarch = job.attributes['hostarch'].value
      arch = job.attributes['arch'].value
      progression = Time.now.to_i - job.attributes['starttime'].value.to_i
      RabbitmqBus.send_to_bus('metrics', "jobs,hostarch=#{hostarch},arch=#{arch},state=building progression=#{progression} count=1")
    end
  end

  def send_scheduler_metrics
    @workerstatus.xpath('//partition//queue').each do |scheduler|
      partition = scheduler.parent.parent.attributes['name']&.value || 'main'
      architecture = scheduler.parent.attributes['arch'].value
      high = scheduler.attributes['high'].value
      low = scheduler.attributes['low'].value
      medium = scheduler.attributes['med'].value
      next_count = scheduler.attributes['next'].value
      RabbitmqBus.send_to_bus('metrics', "scheduler,arch=#{architecture},partition=#{partition} high=#{high} low=#{low} medium=#{medium} next=#{next_count}")
    end
  end
end
