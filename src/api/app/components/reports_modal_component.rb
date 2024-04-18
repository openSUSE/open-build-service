class ReportsModalComponent < ApplicationComponent
  attr_reader :reportable, :reportable_name, :user, :reports

  # TODO: temporary solution until Decision#type replaces Decision#kind with new values
  DECISION_KIND_MAP = { 'cleared' => 'cleared', 'favored' => 'favor' }.freeze

  def initialize(reportable:, reportable_name:, user:, reports:)
    super

    @reportable = reportable
    @reportable_name = reportable_name
    @user = user
    @reports = reports
  end

  def canned_responses
    CannedResponsePolicy::Scope.new(user, CannedResponse).resolve.order(:decision_kind, :title)
  end
end
