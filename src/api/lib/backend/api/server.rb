module Backend
  module Api
    # Class that connect to global endpoints of the OBS Backend server

    class Server
      extend Backend::ConnectionHelper

      # JSON payload of a notification by Id.
      # @param notification [Integer] Notification identifier.
      # @return [String] The JSON encoded structure, depending on the event that
      #   created the notification it will have different payload keys.
      def self.notification_payload(notification)
        get(["/notificationpayload/:notification", notification])
      end

      # Deletes the payload of the notification by Id.
      # @param notification [Integer] Notification identifier.
      # @return [String]
      def self.delete_notification_payload(notification)
        delete(["/notificationpayload/:notification", notification])
      end

      # It writes the configuration of the server
      # @param configuration [String] The content to write in the configuration.
      # @return [String]
      def self.write_configuration(configuration)
        put('/configuration', data: configuration)
      end

      # Latest notifications specifying a starting point
      # @param start [Integer] Starting point for retrieveing the latest notifications.
      # @return [String] Last notifications
      def self.last_notifications(start)
        get("/lastnotifications", params: { start: start, block: 1 })
      end

      # Notifies a certain plugin with the payload
      # @param plugin [String] Plugin identifier.
      # @param payload [Object] Payload to be encoded in JSON.
      # @return [String]
      def self.notify_plugin(plugin, payload)
        post(["/notify_plugins/:plugin", plugin], data: Yajl::Encoder.encode(payload), headers: { 'Content-Type' => 'application/json' })
      end

      # Pings the root of the source repository server
      # @example Sample of the message
      #     <hello name="Source Repository Server" repoid="620451873" />
      # @return [String] Hello message from the server
      def self.root
        get('/')
      end
    end
  end
end
