module Webui::ObsFactory::ApplicationHelper
    def openqa_links_helper
      ObsFactory::OpenqaJob.openqa_links_url
    end
end
