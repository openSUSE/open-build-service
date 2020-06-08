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

# == Schema Information
#
# Table name: commit_activities
#
#  id      :integer          not null, primary key
#  count   :integer          default(0), not null
#  date    :date             not null, indexed => [user_id], indexed => [user_id, project, package]
#  package :string(255)      not null, indexed => [date, user_id, project]
#  project :string(255)      not null, indexed => [date, user_id, package]
#  user_id :integer          not null, indexed, indexed => [date], indexed => [date, project, package]
#
# Indexes
#
#  index_commit_activities_on_user_id           (user_id)
#  index_commit_activities_on_user_id_and_date  (user_id,date)
#  unique_activity_day                          (date,user_id,project,package) UNIQUE
#
