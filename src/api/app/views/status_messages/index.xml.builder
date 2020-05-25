xml.status_messages(count: @count) do
  render(partial: 'status_message', collection: @messages, locals: { builder: xml })
end
