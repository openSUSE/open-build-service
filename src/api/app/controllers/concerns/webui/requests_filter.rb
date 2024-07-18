module Webui::RequestsFilter
  extend ActiveSupport::Concern

  def filter_by_involvement(requests, filter_involvement)
    return requests if filter_involvement == 'all'

    if filter_involvement == 'incoming'
      User.session.incoming_requests
    elsif filter_involvement == 'outgoing'
      User.session.outgoing_requests
    end
  end
end
