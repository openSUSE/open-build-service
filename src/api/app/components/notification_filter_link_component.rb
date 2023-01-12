class NotificationFilterLinkComponent < ApplicationComponent
  def initialize(text:, filter_item:, selected_filter:, amount: 0)
    super

    @text = text
    @filter_item = filter_item
    @selected_filter = selected_filter
    @amount = ensure_integer_amount(amount)
  end

  def css_for_link
    notification_filter_matches? ? 'active' : ''
  end

  def css_for_badge_color
    notification_filter_matches? ? 'bg-light text-dark' : 'bg-primary'
  end

  private

  def notification_filter_matches?
    if @selected_filter[:project].present?
      @filter_item[:project] == @selected_filter[:project]
    elsif @selected_filter[:group].present?
      @filter_item[:group] == @selected_filter[:group]
    elsif @selected_filter[:type].present?
      @filter_item[:type] == @selected_filter[:type]
    else
      @filter_item[:type] == 'unread'
    end
  end

  # This method won't be needed in Ruby 2.6+ by using the option `exception: true` for Integer(...), it's then a one-liner
  def ensure_integer_amount(amount)
    Integer(amount)
  rescue TypeError, ArgumentError
    0
  end
end
