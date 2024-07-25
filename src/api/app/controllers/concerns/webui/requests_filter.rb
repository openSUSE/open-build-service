module Webui::RequestsFilter
  extend ActiveSupport::Concern

  def filter_by_involvement(requests, filter_involvement)
    case filter_involvement
    when 'all'
      requests.where(id: User.session.requests)
    when 'incoming'
      requests.where(id: User.session.incoming_requests)
    when 'outgoing'
      requests.where(id: User.session.outgoing_requests)
    end
  end
end
