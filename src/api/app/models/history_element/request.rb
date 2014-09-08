class HistoryElement::Request < ::HistoryElement::Base
  self.description = 'Request was updated'
  self.abstract_class = true

  def request
    BsRequest.find(self.op_object_id)
  end

  def request=(request)
    self.op_object_id = request.id
  end

  def render_xml(builder)
    attributes = {who: User.find_by_id(self.user_id).login, when: self.created_at.strftime('%Y-%m-%dT%H:%M:%S')}
    builder.history(attributes) do
      builder.description! self.description
      builder.comment! self.comment unless self.comment.blank?
    end
  end
end

class HistoryElement::RequestCreated < HistoryElement::Request
  def description
    'Request created'
  end
end

class HistoryElement::RequestAccepted < HistoryElement::Request
  def description
    'Request got accepted'
  end
end

class HistoryElement::RequestDeclined < HistoryElement::Request
  def description
    'Request got declined'
  end
end

class HistoryElement::RequestRevoked < HistoryElement::Request
  def description
    'Request got revoked'
  end
end

class HistoryElement::RequestSuperseded < HistoryElement::Request
  def description
    desc = 'Request got superseded'
    desc << " by request " << self.description_extension if self.description_extension
    desc
  end

  def initialize(a)
    super
  end
end

class HistoryElement::RequestReviewAdded < HistoryElement::Request
  # self.description_extension is review id
  def description
    'Request got a new review request'
  end
end

class HistoryElement::RequestReviewApproved < HistoryElement::Request
  def description
    'Request got reviewed'
  end
end

class HistoryElement::RequestReopened < HistoryElement::Request
  def description
    'Request got reopened'
  end
end

class HistoryElement::RequestSetIncident < HistoryElement::Request
  def description
    'Maintenance target got moved to project ' + self.description_extension
  end
end

class HistoryElement::RequestPriorityChange < HistoryElement::Request
  def description
    'Request got a new priority: ' + self.description_extension
  end
end

