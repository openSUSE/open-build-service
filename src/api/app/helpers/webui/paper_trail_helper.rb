module Webui::PaperTrailHelper
  include Webui::WebuiHelper

  PAPER_TRAIL_EVENTS = {
    'create' => 'created',
    'update' => 'updated',
    'destroy' => 'destroyed',
    'delete' => 'deleted',
    'moderate' => 'moderated',
    'release' => 'released'
  }.freeze

  def paper_trail_event(event)
    PAPER_TRAIL_EVENTS[event] || 'edited'
  end
end
