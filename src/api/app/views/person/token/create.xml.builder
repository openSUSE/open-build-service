xml.status(code: 'ok') do |status|
  status.summary 'Ok'
  status.data(@token.display_secret, name: 'token')
  status.data(@token.id, name: 'id')
  if @token.is_a?(Token::APIToken) && @token.expires_at.nil?
    status.data('This token never expires. Permanent credentials are bad practice; prefer an expiry.', name: 'warning')
  end
end
