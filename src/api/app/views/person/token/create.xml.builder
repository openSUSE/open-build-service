xml.status(code: 'ok') do |status|
  status.summary 'Ok'
  status.data(@token.display_secret, name: 'token')
  status.data(@token.id, name: 'id')
end
