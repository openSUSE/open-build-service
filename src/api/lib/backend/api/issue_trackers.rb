# frozen_string_literal: true
module Backend
  module Api
    # Class that connect to endpoints related to issue trackers
    class IssueTrackers
      extend Backend::ConnectionHelper

      # It writes the list of issue trackers
      def self.write_list(content)
        http_put('/issue_trackers', data: content)
      end

      # Returns the list of issue trackers
      def self.list
        http_get('/issue_trackers')
      end
    end
  end
end
