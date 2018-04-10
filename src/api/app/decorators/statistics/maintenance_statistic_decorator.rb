# frozen_string_literal: true

module Statistics
  class MaintenanceStatisticDecorator < BaseDecorator
    def to_hash_for_xml
      result = { type: model.type, when: model.when }

      case model.type
      when :issue_created
        result[:name] = model.name
        result[:tracker] = model.tracker
      when :review_accepted, :review_declined, :review_opened
        result[:who] = model.who
        result[:id] = model.id
      end

      result
    end
  end
end
