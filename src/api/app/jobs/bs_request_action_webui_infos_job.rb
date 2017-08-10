class BsRequestActionWebuiInfosJob < ApplicationJob
  queue_as :quick

  def perform(request_action)
    request_action.webui_infos
  end
end
