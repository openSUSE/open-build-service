module Backend::Xml
  class Patchinfo::Issue
    include HappyMapper
    include ActiveModel::Model

    attribute :tracker, String
    attribute :id, String
    attribute :documented, String

    content :summary, String

    validate :issue_tracker_existence

    def object
      issue = Issue.find_or_create_by_name_and_tracker(id, tracker)
      raise Issue::InvalidName, issue.errors.full_messages.to_sentence unless issue.valid?
      issue
    end

    private

    def issue_tracker_existence
      return if IssueTracker.exists?(name: tracker)

      errors.add(:base, "Unknown Issue tracker: '#{tracker}'")
    end
  end
end
