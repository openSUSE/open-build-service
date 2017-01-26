module Statistics
  class MaintenanceStatisticDecorator < BaseDecorator
    def to_hash_for_xml
      if model.type == :issue_created
        {
          type:    model.type,
          name:    model.name,
          tracker: model.tracker,
          when:    model.when
        }
      elsif model.type == :review_accepted || model.type == :review_opened
        {
          type: model.type,
          who:  model.who,
          id:   model.id,
          when: model.when
        }
      else
        default_hash
      end
    end

    def default_hash
      { type: model.type, when: model.when }
    end
  end
end
