xml.status_messages(count: @count) do
  @messages.each do |msg|
    xml.message(
      msg.message,
      msg_id: msg.id,
      user: msg.user.login,
      severity: msg.severity,
      created_at: msg.created_at,
      deleted_at: msg.deleted_at
    )
  end
end
