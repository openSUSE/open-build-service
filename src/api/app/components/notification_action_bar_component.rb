# frozen_string_literal: true

class NotificationActionBarComponent < ApplicationComponent
  attr_accessor :type, :update_path, :show_read_all_button

  def initialize(type:, update_path:, show_read_all_button: false)
    super

    @type = type
    @update_path = add_params(update_path)
    @show_read_all_button = show_read_all_button
  end

  def button_text(all: false)
    text = type == 'read' ? 'Unread' : 'Read'
    if all
      "Mark all as '#{text}'"
    else
      "Mark selected as '#{text}'"
    end
  end

  def disable_with_content(all: false)
    spinner = tag.i(class: 'fas fa-spinner fa-spin ms-2')
    button_text(all: all) + spinner
  end

  private

  def add_params(path)
    return path + '&update_all=true' if path.include?('?')

    path + '?update_all=true'
  end
end
