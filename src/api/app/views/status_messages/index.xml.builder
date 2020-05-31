xml.status_messages(count: @count) do
  render(partial: 'status_messages/status_message', collection: @status_messages, locals: { builder: xml })
end
