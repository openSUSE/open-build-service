module Webui::Projects::AttributesHelper
  def category_badge(category)
    return unless category
    badge_type = case category
                 when 'Stable'
                   'badge-success'
                 when 'Testing'
                   'badge-warning'
                 when 'Development'
                   'badge-info'
                 else
                   'badge-dark'
                 end
    content_tag(:span, category, class: "quality-category badge #{badge_type}")
  end
end
