HoptoadNotifier.configure do |config|
  # Change this to some sensible data for your errbit instance
  config.api_key = CONFIG['errbit_api_key'] || 'YOUR_ERRBIT_API_KEY'
  config.host    = CONFIG['errbit_host'] || 'YOUR_ERRBIT_HOST'
  if CONFIG['errbit_api_key'].blank? || CONFIG['errbit_host'].blank?
    config.development_environments = "production development test"
  else
    config.development_environments = "development test"  
  end
  # We don't want to know about timeout errors, the api will tell us the real reason 
  config.ignore << Timeout::Error
  # The api sometimes sends responses without a proper "Status:..." line (when it restarts?)
  config.ignore << Net::HTTPBadResponse 
end
