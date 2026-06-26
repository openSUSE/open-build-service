xml.configuration do
  keys = Configuration::OPTIONS_YML.keys
  keys.each do |key|
    value = my_model.send(key.to_s)
    next if value.nil?

    if Configuration::ON_OFF_OPTIONS.include? key
      value = value ? 'on' : 'off'
    end
    xml.send(key.to_s, value)
  end

  xml.schedulers do
    Architecture.where(available: 1).find_each do |arch|
      xml.arch(arch.name)
    end
  end
end
