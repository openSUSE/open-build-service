class DecisionFavoredWithPackageDeletion < Decision
  after_create :create_event
  after_create :delete_package

  def description
    'The moderator decided to favor the report and initiated the package deletion'
  end

  def self.display_name
    'favor and delete the package'
  end

  def self.display?(reportable)
    return false unless reportable.is_a?(Package)

    true
  end

  def delete_package
    reportable = reports.first.reportable
    return unless reportable.is_a?(Package)

    reportable.destroy
  end

  def deletes_target_record?
    true
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
