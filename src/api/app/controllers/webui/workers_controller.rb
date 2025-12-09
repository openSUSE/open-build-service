class Webui::WorkersController < Webui::WebuiController
  def show
    @architecture = params.require(:arch)
    @worker_id = params.require(:worker_id)
    @worker_label = "#{@architecture}:#{@worker_id}"

    capability_xml = Backend::Api::Worker.capability(@worker_label)
    capability_hash = Hash.from_xml(capability_xml).fetch('worker', {})

    @capability = capability_hash
    @linux_info = capability_hash.fetch('linux', {}) || {}
    hardware = capability_hash.fetch('hardware', {}) || {}
    cpu_info = hardware.fetch('cpu', {}) || {}
    @cpu_flags = Array(cpu_info['flag']).compact
    @hardware_info = hardware.except('cpu')
  rescue Backend::NotFoundError => e
    flash[:error] = _('Worker not found')
    redirect_to monitor_path
  rescue Backend::Error => e
    flash[:error] = e.message
    redirect_to monitor_path
  end
end

