# frozen_string_literal: true

xml.comments(@header) do
  render(partial: 'comments', locals: { builder: xml, comments: @comments })
end
