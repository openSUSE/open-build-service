xml.assignments(count: assignments.size, project: project) do
  assignments.each do |assignment|
    xml.assignment(package: assignment.package.name) do |xml_assignment|
      xml_assignment.assigner   assignment.assigner.login
      xml_assignment.assignee   assignment.assignee.login
      xml_assignment.created_at assignment.created_at
      xml_assignment.updated_at assignment.updated_at
    end
  end
end
