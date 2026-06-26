module HistoryElement
  class RequestSetIncident < HistoryElement::Request
    def color
      'black'
    end

    def description
      "Maintenance target got moved to project #{description_extension}"
    end

    def user_action
      "moved maintenance target to #{description_extension}"
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
