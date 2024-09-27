class ReportsModalComponent < ApplicationComponent
  attr_reader :reportable, :reportable_name, :user, :reports

  def initialize(reportable:, reportable_name:, user:, reports:)
    super

    @reportable = reportable
    @reportable_name = reportable_name
    @user = user
    @reports = reports
  end

  def canned_responses
    user.canned_responses.order(:decision_type, :title)
  end
end
