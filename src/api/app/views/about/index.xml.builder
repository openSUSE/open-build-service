xml.about do
  xml.title 'Open Build Service API'
  xml.description 'API to the Open Build Service'
  xml.revision @api_revision
  xml.last_deployment @last_deployment if @last_deployment.present?
  xml.commit @commit if @commit.present?
end
