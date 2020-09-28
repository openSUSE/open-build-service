module Webui::FlashHelper
  def flash_content(flash)
    if flash.is_a?(Hash)
      capture_haml do
        haml_tag(:span, flash.delete(:title))
        haml_tag :ul do
          flash.each do |name, messages|
            haml_tag(:li, name, class: 'no-bullet')
            haml_tag :ul do
              messages.each { |message| haml_tag(:li, message) }
            end
          end
        end
      end
    else
      body = flash.gsub(/\\n/, '')
      sanitize(body, tags: ['a', 'b', 'ul', 'li', 'br', 'u'], attributes: ['href', 'title'])
    end
  end
end
