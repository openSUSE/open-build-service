# Report class flags abusive content, be it projects, packages, users or comments
class Report < ApplicationRecord
  REPORTABLE_TYPES = %i[Comment Package Project User BsRequest].freeze
  REPORTABLE_TYPES_STRINGS = {
    Comment: 'comment',
    Package: 'package',
    Project: 'project',
    User: 'user',
    BsRequest: 'request'
  }.freeze

  validates :reason, length: { maximum: 65_535 }
  validates :reportable_type, length: { maximum: 255 }
  validates :reportable, presence: true, on: :create

  belongs_to :reporter, class_name: 'User', optional: false
  belongs_to :reportable, polymorphic: true, optional: true
  has_many :comments, as: :commentable, dependent: :destroy

  belongs_to :decision, optional: true

  enum :category, {
    spam: 10,
    scam: 20,
    forbidden_license: 30,
    illegal_content: 40,
    other: 99
  }

  after_create :create_event
  after_create :track_report

  validate :reports_pointing_to_same_reportable

  scope :without_decision, -> { where(decision: nil) }

  private

  def create_event
    case reportable_type
    when 'Comment'
      Event::ReportForComment.create(event_parameters_for_comment(commentable: reportable.commentable).merge(commenter: reportable.user.login))
    when 'Package'
      Event::ReportForPackage.create(event_parameters.merge(package_name: reportable.name,
                                                            project_name: reportable.project.name))
    when 'Project'
      Event::ReportForProject.create(event_parameters.merge(project_name: reportable.name))
    when 'User'
      Event::ReportForUser.create(event_parameters.merge(accused: reportable.login))
    when 'BsRequest'
      Event::ReportForRequest.create(event_parameters.merge(bs_request_number: reportable.number))
    end
  end

  def event_parameters
    { id: id, reporter: reporter.login, reportable_id: reportable_id, reportable_type: reportable_type, reason: reason, category: category }
  end

  def event_parameters_for_comment(commentable:)
    case commentable
    when BsRequest
      event_parameters.merge(commentable_type: commentable.class.name, bs_request_number: commentable.number)
    when BsRequestAction
      event_parameters.merge(commentable_type: commentable.class.name, bs_request_number: commentable.bs_request.number,
                             bs_request_action_id: commentable.id)
    when Package
      event_parameters.merge(commentable_type: commentable.class.name, package_name: commentable.name,
                             project_name: commentable.project.name)
    when Project
      event_parameters.merge(commentable_type: commentable.class.name, project_name: commentable.name)
    end
  end

  def track_report
    RabbitmqBus.send_to_bus('metrics', "report,category=#{category},type=#{reportable_type} sibling_reports=#{ReportsFinder.new(self).siblings},count=1")
  end

  def reports_pointing_to_same_reportable
    return unless decision && decision.reports.where.not(reportable: reportable).present?

    errors.add(:base, :decision_with_different_reportables, message: 'Decision has reports pointing to a different reportable. All decision reports should point to same reportable.')
  end
end

# == Schema Information
#
# Table name: reports
#
#  id              :bigint           not null, primary key
#  category        :integer          default("other")
#  reason          :text(65535)
#  reportable_type :string(255)      indexed => [reportable_id]
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  decision_id     :bigint           indexed
#  reportable_id   :integer          indexed => [reportable_type]
#  reporter_id     :integer          not null, indexed
#
# Indexes
#
#  index_reports_on_decision_id  (decision_id)
#  index_reports_on_reportable   (reportable_type,reportable_id)
#  index_reports_on_reporter_id  (reporter_id)
#
# Foreign Keys
#
#  fk_rails_...  (decision_id => decisions.id) ON DELETE => nullify
#  fk_rails_...  (reporter_id => users.id)
#
