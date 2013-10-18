class Webui::Collection < Webui::Node
  def is_empty?
    return !self.has_elements?
  end
end
