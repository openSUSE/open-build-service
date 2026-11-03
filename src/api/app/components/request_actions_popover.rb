# Popovers listing request actions one per line. They stay open while hovered (see webui/popover.js),
# so long lists can be scrolled.
module RequestActionsPopover
  # Longer lists are cut, the request page lists all of them
  POPOVER_LIMIT = 25

  private

  # Data attributes of a popover listing one item per line
  def popover_data(items)
    lines = items.first(POPOVER_LIMIT)
    lines += [tag.span("and #{items.size - POPOVER_LIMIT} more, see the request", class: 'text-secondary')] if items.size > POPOVER_LIMIT
    content = tag.ul(safe_join(lines.map { |line| tag.li(line) }), class: 'list-unstyled mb-0')
    { request_actions_popover: true, bs_html: 'true', bs_custom_class: 'request-actions-popover', bs_content: content }
  end
end
