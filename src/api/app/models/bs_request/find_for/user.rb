class BsRequest
  module FindFor
    class User < Base
      include UserGroupMixin

      def all
        inner_or = []
        user = ::User.find_by_login!(user_login)

        # user's own submitted requests
        if roles.empty? || roles.include?('creator')
          inner_or << "bs_requests.creator = #{quote(user.login)}"
        end
        # find requests where user is maintainer in target project
        @relation, inner_or = extend_query_for_maintainer(user, @relation, roles, inner_or)
        if roles.empty? || roles.include?('reviewer')
          @relation = @relation.includes(:reviews).references(:reviews)

          # requests where the user is reviewer or own requests that are in review by someone else
          or_in_and = %W[reviews.by_user=#{quote(user.login)}]

          # include all groups of user
          usergroups = user.groups.map { |group| "'#{group.title}'" }
          or_in_and << "reviews.by_group in (#{usergroups.join(',')})" if usergroups.present?

          @relation, inner_or = extend_query_for_involved_reviews(user, or_in_and, @relation, review_states, inner_or)
        end
        if inner_or.empty?
          @relation.none
        else
          @relation.where(inner_or.join(' or '))
        end
      end
    end
  end
end
