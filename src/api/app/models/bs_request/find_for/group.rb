class BsRequest
  module FindFor
    class Group < Base
      include UserGroupMixin

      def all
        query = union_query
        @relation = if query.present?
                      @relation.where("bs_requests.id IN (#{query})")
                    else
                      @relation.none
                    end
      end

      def all_count
        ActiveRecord::Base.connection.execute("SELECT COUNT(bs_request_id) FROM (#{union_query}) x").first.first
      end

      private

      def group
        @group ||= ::Group.find_by_title!(group_title)
      end

      def union_query
        query_parts = []
        query_parts << bs_request_actions_query.to_sql if bs_request_actions_query
        query_parts << reviews_query.to_sql if reviews_query
        query_parts.join(' UNION ')
      end

      def bs_request_actions_query
        return unless roles.empty? || roles.include?('maintainer')

        @bs_request_actions_query ||= bs_request_actions(group).select(:bs_request_id)
      end

      def reviews_query
        return unless roles.empty? || roles.include?('reviewer')

        @reviews_query ||= reviews(group, review_states).select(:bs_request_id)
      end
    end
  end
end
