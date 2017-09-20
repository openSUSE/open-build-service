# API for accessing to the backend
module Backend
  module Api
    class Server
      # Returns the notification payload for that key (from src/api/app/models/binary_release.rb)
      def self.notification_payload(key)
        Backend::Connection.get("/notificationpayload/#{key}").body
      end

      # Deletes the notification payload for that key (from src/api/app/models/binary_release.rb)
      def self.delete_notification_payload(key)
        Backend::Connection.delete("/notificationpayload/#{key}")
      end

      # It writes the configuration XML
      def self.write_configuration(xml)
        Backend::Connection.put('/configuration', xml)
      end

      # Returns the latest notifications specifying a starting point
      def self.last_notifications(start)
        Backend::Connection.get("/lastnotifications?start=#{CGI.escape(start.to_s)}&block=1").body
      end

      # Notifies a certain plugin with the payload
      def self.notify_plugin(plugin, payload)
        Backend::Connection.post("/notify_plugins/#{plugin}", Yajl::Encoder.encode(payload), 'Content-Type' => 'application/json').body
      end

      # Pings the root of the backend
      def self.root
        Backend::Connection.get('/').body.force_encoding("UTF-8")
      end
    end
  end
end
