module HistoryElement
  class Review < HistoryElement::Base
    self.description = 'Review was updated'
    self.abstract_class = true

    def review
      Review.find(op_object_id)
    end

    def request
      Review.find(op_object_id).bs_request
    end

    def review=(review)
      self.op_object_id = review.id
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
