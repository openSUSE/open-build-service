xml.label_templates(count: @label_templates.size) do
  @label_templates.each do |label_template|
    xml.label_template(id: label_template.id) do |xml_lt|
      xml_lt.color      label_template.color
      xml_lt.name       label_template.name
      xml_lt.created_at label_template.created_at
      xml_lt.updated_at label_template.updated_at
    end
  end
end
