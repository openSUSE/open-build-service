class CommitActivity < ApplicationRecord
  belongs_to :user

  validates :user, :date, :project, :package, :count, presence: true

  validates :count, numericality: { more_than_or_equal_to: 1,
                                    only_integer: true }

  def self.create_from_event_payload(payload)
    user = User.find_by(login: payload['user'])
    return unless user

    attributes = { user: user, date: Time.zone.today,
                   project: payload['project'], package: payload['package'] }
    begin
      CommitActivity.create(attributes.merge(count: 1))
    rescue ActiveRecord::RecordNotUnique
      # rubocop:disable Rails/SkipsModelValidations
      CommitActivity.find_by!(attributes).increment!(:count)
      # rubocop:enable Rails/SkipsModelValidations
    end
  end
end
