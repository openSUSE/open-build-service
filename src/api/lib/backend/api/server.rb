# API for accessing to the backend
module Backend
  module Api
    class Server
      extend Backend::ConnectionHelper

      # Returns the notification payload
      def self.notification_payload(notification)
        get(["/notificationpayload/:notification", notification])
      end

      # Deletes the notification payload
      def self.delete_notification_payload(notification)
        delete(["/notificationpayload/:notification", notification])
      end

      # It writes the configuration
      def self.write_configuration(configuration)
        put('/configuration', data: configuration)
      end

      # Returns the latest notifications specifying a starting point
      def self.last_notifications(start)
        get("/lastnotifications", params: { start: start, block: 1 })
      end

      # Notifies a certain plugin with the payload
      def self.notify_plugin(plugin, payload)
        post(["/notify_plugins/:plugin", plugin], data: Yajl::Encoder.encode(payload), headers: { 'Content-Type' => 'application/json' })
      end

      # Pings the root of the backend
      def self.root
        get('/')
      end
    end
  end
end
