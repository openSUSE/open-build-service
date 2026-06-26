xml.canned_responses(count: @count) do
  render(partial: 'canned_response', collection: @canned_responses, locals: { builder: xml })
end
