class BsRequest
  module FindFor
    class User < Base
      include UserGroupMixin

      def all
        query = union_query
        @relation = if query.present?
                      @relation.where("bs_requests.id IN (#{query})")
                    else
                      @relation.none
                    end
      end

      private

      def user
        @user = ::User.find_by_login!(user_login)
      end

      def union_query
        query_parts = []
        # we're inside a scope, so a BsRequest.where can leak other scopes -> unscoped
        query_parts << BsRequest.unscoped.where(creator: user.login).select(:id).to_sql if roles.empty? || roles.include?('creator')
        query_parts << bs_request_actions_query.to_sql if bs_request_actions_query
        query_parts << reviews_query.to_sql if reviews_query
        query_parts.join(' UNION ')
      end

      def bs_request_actions_query
        return unless roles.empty? || roles.include?('maintainer')

        @bs_request_actions_query ||= bs_request_actions(user).select(:bs_request_id)
      end

      def reviews_query
        return unless roles.empty? || roles.include?('reviewer')

        @reviews_query ||= reviews(user, review_states).select(:bs_request_id)
      end
    end
  end
end
