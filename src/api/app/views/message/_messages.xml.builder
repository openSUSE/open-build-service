

root_attrs = {}
root_attrs[:count] = @messages.length if @messages
root_attrs[:project] = @project.name if @project
root_attrs[:package] = @package.name if @package

xml.messages(root_attrs) do
  @messages.each do |msg|
    attrs = {}
    attrs[:severity] = msg.severity or attrs[:severity] = 0
    attrs[:sent_at] = msg.sent_at.xmlschema if msg.sent_at
    attrs[:user] =  msg.user.login if msg.user
    msg.send_mail ? attrs[:send_mail] = true : attrs[:send_mail] = false
    msg.private ? attrs[:private] = true : attrs[:private] = false

    xml.message(
      msg.text,
      attrs,
      :msg_id => msg.id,
      :created_at => msg.created_at.xmlschema
    )
  end
end
