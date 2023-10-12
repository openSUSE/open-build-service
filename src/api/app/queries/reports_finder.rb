class ReportsFinder
  def initialize(report, relation = Report.all)
    @report = report
    @relation = relation
  end

  def siblings
    @relation.where(category: @report.category, reportable: @report.reportable).count
  end
end
