# frozen_string_literal: true

class NotificationActionBarComponent < ApplicationComponent
  attr_accessor :state, :update_path, :counted_notifications

  def initialize(state:, update_path:, counted_notifications:)
    super

    @state = state
    @update_path = toggle_update_path_states(update_path)
    @counted_notifications = counted_notifications
  end

  def button_text(all: false)
    text = %w[all unread].include?(state) ? 'Read' : 'Unread'
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

  def toggle_update_path_states(path)
    toggled_state = state == 'unread' ? 'read' : 'unread'
    uri = Addressable::URI.parse(path)
    uri.query_values = (uri.query_values || {}).merge('button' => toggled_state, 'update_all' => true)

    uri.to_s
  end
end
