module Backend
  module Api
    # Class that connect to endpoints related to issue trackers
    class IssueTrackers
      extend Backend::ConnectionHelper

      # It writes the list of issue trackers
      def self.write_list(content)
        put('/issue_trackers', data: content)
      end

      # Returns the list of issue trackers
      def self.list
        get('/issue_trackers')
      end
    end
  end
end
