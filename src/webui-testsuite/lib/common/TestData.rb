# ==============================================================================
# 
#
class TestData
  
  
  # ============================================================================
  # We catch method_missing events to allow easy set and get of
  # any possible variable in the data class without the need to
  # declare them. This might not be needed when the project gets
  # mature and it's clear what all the setting variables would be
  #
  def method_missing name, *args
    name = name.to_s
    if name =~ (/=$/)
      instance_variable_set("@#{name.chop}", args.first)
    else
      instance_variable_get("@#{name}")
    end
  end
  
  
end
