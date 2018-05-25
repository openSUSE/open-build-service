module ObsFactory
  class ApplicationController < ::Webui::WebuiController
    layout 'obs_factory/application'

    rescue_from ObsFactory::OpenqaApi::OpenqaFailure do |ex|
      render text: "failure in openQA"
    end
  end
end
