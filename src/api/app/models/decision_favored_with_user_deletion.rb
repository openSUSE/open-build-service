class DecisionFavoredWithUserDeletion < Decision
  after_create :create_event
  after_create :delete_user

  def description
    'The moderator decided to favor the report and delete the user'
  end

  def self.display_name
    'favor and delete the user'
  end

  def self.display?(reportable)
    [Comment, BsRequest, User].any? { |c| reportable.is_a?(c) }
  end

  def delete_user
    reportable = reports.first.reportable
    user = case reportable
           when Comment
             reportable.user
           when BsRequest
             User.find_by(login: reportable.creator)
           when User
             reportable
           else
             return
           end

    user.delete!(adminnote: reason)
  end

  private

  def create_event
    Event::FavoredDecision.create(event_parameters)
  end
end

# == Schema Information
#
# Table name: decisions
#
#  id           :bigint           not null, primary key
#  reason       :text(65535)      not null
#  type         :string(255)      default("DecisionCleared"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  moderator_id :integer          not null, indexed
#
# Indexes
#
#  index_decisions_on_moderator_id  (moderator_id)
#
# Foreign Keys
#
#  fk_rails_...  (moderator_id => users.id)
#
