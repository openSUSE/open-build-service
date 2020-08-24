root_attrs = {}
root_attrs[:count] = @messages.length if @messages
root_attrs[:project] = @project.name if @project
root_attrs[:package] = @package.name if @package

xml.messages(root_attrs) do
  @messages.each do |msg|
    attrs = {}
    attrs[:severity] = msg.severity || 0
    attrs[:sent_at] = msg.sent_at.xmlschema if msg.sent_at
    attrs[:user] =  msg.user.login if msg.user
    attrs[:send_mail] = msg.send_mail
    attrs[:private] = msg.private

    xml.message(
      msg.text,
      attrs,
      msg_id: msg.id,
      created_at: msg.created_at.xmlschema
    )
  end
end
