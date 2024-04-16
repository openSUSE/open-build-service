class AddApiEndpointsToPayload < ActiveRecord::Migration[6.1]
  def up
    EventSubscription.where(channel: 'scm').find_each do |event_sub|
      next if event_sub.payload['api_endpoint'].present?

      if event_sub.payload['scm'] == 'github'
        event_sub.payload['api_endpoint'] = 'https://api.github.com'
      else
        http_url = event_sub.payload['http_url']
        uri = URI.parse(http_url)
        api_endpoint = "#{uri.scheme}://#{uri.host}"
        event_sub.payload['api_endpoint'] = api_endpoint
      end
      event_sub.save!
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
