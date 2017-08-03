class BsRequestActionWebuiInfosJob < ApplicationJob
  queue_as :quick

  def perform(request_action_id)
    BsRequestAction.find(request_action_id).webui_infos
  end
end
