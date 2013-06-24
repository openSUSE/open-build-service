xml.configuration do
  xml.title @configuration.title
  xml.description @configuration.description
  xml.name @configuration.name
  xml.schedulers do
    @architectures.each do |a|
      xml.arch a.name
    end
  end
end

