xml.history do
  StatusHelper.resample(@values, @samples).each do |time, val|
    xml.value(time: time,
              value: val) # for debug, :timestring => Time.at(time)  )
  end
end
