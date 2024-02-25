# frozen_string_literal: true

class Webui::WorkerCapabilitiesController < Webui::WebuiController
  def show
    cache_key = "worker_capabilities_#{params[:arch]}_#{params[:id]}"

    xml_data = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      Backend::Api::BuildResults::Worker.capabilities(params[:arch], params[:id])
    end || ''

    capabilities = Xmlhash.parse(xml_data)
    @num_of_processors = capabilities&.dig('hardware', 'processors')
    @num_of_jobs = capabilities&.dig('hardware', 'jobs')
  end
end
