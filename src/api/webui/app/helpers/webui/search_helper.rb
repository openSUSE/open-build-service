module Webui::SearchHelper

  def description_text(obj)
    desc = nil
    if obj.respond_to?(:has_element?) && obj.has_element?("description")
      desc = obj.description.to_s
    elsif obj.respond_to?(:has_key?) && obj.has_key?("description")
      desc = obj["description"].to_s
    else
      return nil
    end
    if desc.empty?
      nil
    else
      desc[0,80] + "..."
    end
  end
end
