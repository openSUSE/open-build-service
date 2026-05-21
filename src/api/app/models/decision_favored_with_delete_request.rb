class DecisionFavoredWithDeleteRequest < Decision
  attr_reader :bs_request

  after_create :create_event
  after_create :create_delete_request

  def description
    "The moderator decided to favor the report and ask for the #{reportable.class.name.downcase}'s deletion"
  end

  def self.display_name
    'favor and create a delete request'
  end

  def self.display?(reportable)
    return false unless reportable.is_a?(Project) || reportable.is_a?(Package)

    true
  end

  def create_delete_request
    reportable = reports.first.reportable
    return unless reportable.is_a?(Project) || reportable.is_a?(Package)

    @bs_request = BsRequest.new
    @bs_request.description = "After evaluation, the moderators decided to remove the #{reportable.class.name.downcase} with the following reason: #{reason}"
    opts = if reportable.is_a?(Project)
             { target_project: reportable.name }
           else
             { target_package: reportable.name, target_project: reportable.project.name }
           end
    action = BsRequestActionDelete.new(opts)
    @bs_request.bs_request_actions << action

    @bs_request.save!
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
