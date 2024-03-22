module HistoryElement
  class RequestReviewAdded < HistoryElement::Request
    def description
      'Request got a new review request'
    end

    def user_action
      return 'added a reviewer' unless review

      "#{user_action_prefix} #{action_target} #{user_action_suffix}"
    end

    def user_action_prefix
      return 'set' if review_by_staging_project?

      'added'
    end

    def action_target
      review.reviewed_by
    end

    def user_action_suffix
      return 'as a staging project' if review_by_staging_project?

      'as a reviewer'
    end

    # self.description_extension is review id, but it's not present in old history elements
    def review
      return if description_extension.blank?

      ::Review.find(description_extension)
    end

    def review_by_staging_project?
      review&.staging_project?
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
