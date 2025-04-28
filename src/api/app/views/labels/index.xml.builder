xml.labels(count: @labels.length) do
  @labels.each do |label|
    xml.label do
      xml.id(label.id)
      xml.label_template_id(label.label_template.id)
      xml.label_template_name(label.label_template.name)
      xml.label_template_color(label.label_template.color)
    end
  end
end
