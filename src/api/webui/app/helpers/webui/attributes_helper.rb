module Webui::AttributesHelper

  def attribute_to_s attribute
    attribute.each_value.collect{|a| a.to_s + ', '
    }.to_s.chop.chop
  end

end


