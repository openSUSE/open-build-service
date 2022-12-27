module Webui::Projects::CategoryHelper
  def category_badge(category)
    return unless category

    badge_type = case category
                 when 'Stable'
                   'bg-success'
                 when 'Testing'
                   'bg-warning'
                 when 'Development'
                   'bg-info'
                 else
                   'bg-dark'
                 end
    tag.span(category, class: "quality-category badge ms-1 #{badge_type}")
  end
end
