xml.status(code: "ok") do |status|
  status.summary "Ok"
  status.data(@token.string, { :name => "token" })
end

