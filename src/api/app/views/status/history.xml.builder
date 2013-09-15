xml.history do
  StatusHelper.resample(@values, @samples).each do |time, val|
    builder.value(:time => time,
                  :value => val) # for debug, :timestring => Time.at(time)  )
  end
end