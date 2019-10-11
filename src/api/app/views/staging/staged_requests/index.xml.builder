xml.staged_requests do
  render(partial: 'staging/shared/requests', locals: { requests: @requests, builder: xml })
end
