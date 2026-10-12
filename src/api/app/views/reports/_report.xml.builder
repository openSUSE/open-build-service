reportable = {}
case report.reportable
when Package
  reportable[:project] = report.reportable.project.name
  reportable[:package] = report.reportable.name
when Project
  reportable[:project] = report.reportable.name
when BsRequest
  reportable[:bsrequest] = report.reportable.number
when Comment
  reportable[:comment] = report.reportable_id
when User
  reportable[:user] = report.reportable.login
end

builder.report(reportable.merge(id: report.id, category: report.category,
                                created_at: report.created_at, updated_at: report.updated_at)) do
  builder.text(report.reason)
end
