xml.status_messages(count: @count) do
  render(partial: 'status_message', collection: @status_messages, locals: { builder: xml })
end
