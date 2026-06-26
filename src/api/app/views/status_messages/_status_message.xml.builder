builder.status_message(id: status_message.id) do |m|
  m.message status_message.message
  m.user status_message.user.login
  m.severity status_message.severity
  m.scope status_message.communication_scope
  m.created_at status_message.created_at
end
