xml.maintenanceincident(project: @project.name) do
  @maintenance_statistics.each do |statistics|
    xml_attributes = { type: statistics.type, when: statistics.when }
    case statistics.type
    when :issue_created
      xml.entry(xml_attributes.merge(name: statistics.name, tracker: statistics.tracker))
    when :review_accepted, :review_declined, :review_opened
      xml.entry(xml_attributes.merge(who: statistics.who, id: statistics.id))
    else
      xml.entry(xml_attributes)
    end
  end
end
