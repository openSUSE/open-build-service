module Webui::Projects::CategoryHelper
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
    tag.span(category, class: "quality-category badge ml-1 #{badge_type}")
  end
end
