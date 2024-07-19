module Webui::RequestsFilter
  extend ActiveSupport::Concern

  def filter_by_involvement(requests, filter_involvement)
    return requests if filter_involvement == 'all'

    if filter_involvement == 'incoming'
      requests.where(User.session.incoming_requests)
    elsif filter_involvement == 'outgoing'
      requests.where(User.session.outgoing_requests)
    end
  end
end
