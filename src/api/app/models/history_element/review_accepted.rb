module HistoryElement
  class ReviewAccepted < HistoryElement::Review
    def description
      'Review got accepted'
    end

    # True when the accepted review was created because the request was staged in a staging workflow —
    # in that case the review also belongs to the staging workflow's managers group.
    def staged_review?
      review.for_group? && request.staged_request? &&
        review.by_group == request.staging_project.staging_workflow.managers_group.title
    end
  end
end

# == Schema Information
#
# Table name: history_elements
#
#  id                    :integer          not null, primary key
#  comment               :text(65535)
#  description_extension :string(255)
#  type                  :string(255)      not null, indexed, indexed => [op_object_id]
#  created_at            :datetime         not null, indexed
#  op_object_id          :integer          not null, indexed => [type]
#  user_id               :integer          not null
#
# Indexes
#
#  index_history_elements_on_created_at  (created_at)
#  index_history_elements_on_type        (type)
#  index_search                          (op_object_id,type)
#
