# Always allow requests from localhost
Rack::Attack.safelist('allow from localhost') do |request|
  ['127.0.0.1:3000', 'localhost:3000'].include?(request.env['HTTP_HOST'])
end

# Always allow requests from these IPs
# Rack::Attack.safelist_ip("....")

# Inform user how many seconds to wait until they can start sending requests again
Rack::Attack.throttled_response_retry_after_header = true

# Track requests by IP: 15 requests/minute
Rack::Attack.throttle("requests by ip", limit: ENV.fetch('THROTTLE_REQUESTS_LIMIT', 15), period: ENV.fetch('THROTTLE_TIME', 60), &:ip)

# Response of blocklisted and throttled requests
Rack::Attack.throttled_responder = lambda do |request|
  match_data = request.env['rack.attack.match_data']
  now = match_data[:epoch_time]

  headers = {
    'RateLimit-Limit' => match_data[:limit].to_s,
    'RateLimit-Remaining' => '0',
    'RateLimit-Reset' => (now + (match_data[:period] - (now % match_data[:period]))).to_s
  }

  [429, headers, ["You have exceeded the allowed rate limit. Try again in 60 seconds.\n"]]
end
