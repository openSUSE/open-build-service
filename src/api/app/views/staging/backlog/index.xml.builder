xml.backlog do
  render(partial: 'staging/shared/requests', locals: { requests: @backlog, builder: xml })
end
