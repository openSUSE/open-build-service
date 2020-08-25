module AppendSphinxCallbacks
  extend ActiveSupport::Concern

  included do
    ThinkingSphinx::Callbacks.append(self, behaviours: [:real_time]) do |record|
      # Index record only if its name, title or description changed
      if record.name_previously_changed? || record.title_previously_changed? || record.description_previously_changed?
        [record]
      else
        []
      end
    end
  end
end
