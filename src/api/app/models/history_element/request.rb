module HistoryElement
  class Request < HistoryElement::Base
    self.description = 'Request was updated'
    self.abstract_class = true

    def request
      BsRequest.find(op_object_id)
    end

    def request=(request)
      self.op_object_id = request.id
    end

    def render_xml(builder)
      attributes = { who: user.login, when: created_at.strftime('%Y-%m-%dT%H:%M:%S') }
      builder.history(attributes) do
        builder.description!(description)
        builder.comment!(comment) if comment.present?
      end
    end
  end
end
