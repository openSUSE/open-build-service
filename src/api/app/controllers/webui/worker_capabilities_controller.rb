# frozen_string_literal: true

class Webui::WorkerCapabilitiesController < Webui::WebuiController
  def show
    xml_data = Backend::Api::BuildResults::Worker.capabilities(params[:arch], params[:id])
    capabilities = Xmlhash.parse(xml_data)

    @num_of_processors = capabilities.dig('hardware', 'processors')
    @num_of_jobs = capabilities.dig('hardware', 'jobs')
  end
end
