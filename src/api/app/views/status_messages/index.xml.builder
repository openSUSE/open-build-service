xml.status_messages(count: @count) do
  @messages.each do |msg|
    xml.status_message(id: msg.id) do |m|
      m.message msg.message
      m.user msg.user.login
      m.severity msg.severity
      m.created_at msg.created_at
    end
  end
end
