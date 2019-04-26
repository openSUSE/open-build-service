xml.comments(@header) do
  render(partial: 'comment', collection: @comments, locals: { obj_is_user: @obj.is_a?(User),
                                                              builder: xml })
end
