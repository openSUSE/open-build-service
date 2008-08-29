xml.instruct!
xml.wizard("last" => @wizard_form.last ? "true" : "false") do
  xml.label(@wizard_form.label)
  xml.legend(@wizard_form.legend)
  @wizard_form.entries.each do |entry|
    xml.entry("name" => entry.name, "type" => entry.type) do
      xml.label(entry.label)
      xml.legend(entry.legend)
      xml.value(entry.value)
      if entry.options
        entry.options.each do |option|
          xml.option("name" => option.name) do
            xml.label(option.label)
            xml.legend(option.legend)
          end
        end
      end
    end
  end
end

# vim:et:ts=2:sw=2
