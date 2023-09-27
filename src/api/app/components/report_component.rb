# rubocop:disable ViewComponent/MissingPreviewFile
# frozen_string_literal: true

class ReportComponent < ApplicationComponent
  def initialize(reportable:)
    super

    @reportable = reportable
  end
end
# rubocop:enable ViewComponent/MissingPreviewFile
