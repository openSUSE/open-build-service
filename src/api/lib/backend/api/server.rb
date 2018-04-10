# frozen_string_literal: true

module Backend
  module Api
    # Class that connect to global endpoints of the OBS Backend server

    class Server
      extend Backend::ConnectionHelper

      # JSON payload of a notification by Id.
      # @return [String]
      def self.notification_payload(notification_id)
        http_get(['/notificationpayload/:notification', notification_id])
      end

      # Deletes the payload of the notification by Id.
      # @return [String]
      def self.delete_notification_payload(notification_id)
        http_delete(['/notificationpayload/:notification', notification_id])
      end

      # It writes the configuration of the server
      # @return [String]
      def self.write_configuration(configuration)
        http_put('/configuration', data: configuration)
      end

      # Latest notifications specifying a starting point
      # @param starting_point [Integer]
      # @return [String] Last notifications
      def self.last_notifications(starting_point)
        http_get('/lastnotifications', params: { start: starting_point, block: 1 })
      end

      # Notifies a certain plugin with the payload
      # @param plugin_id [String]
      # @return [String]
      def self.notify_plugin(plugin_id, payload)
        http_post(['/notify_plugins/:plugin', plugin_id],
                  data: ActiveSupport::JSON.encode(payload), headers: { 'Content-Type' => 'application/json' })
      end

      # Pings the root of the source repository server
      # @return [String] Hello message from the server
      def self.root
        http_get('/')
      end
    end
  end
end
