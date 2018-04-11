# frozen_string_literal: true

class BsRequest
  module FindFor
    class Group < Base
      include UserGroupMixin

      def all
        inner_or = []
        group = ::Group.find_by_title!(group_title)

        # find requests where group is maintainer in target project
        @relation, inner_or = extend_query_for_maintainer(group, @relation, roles, inner_or)

        if roles.empty? || roles.include?('reviewer')
          @relation = @relation.includes(:reviews).references(:reviews)
          # requests where the user is reviewer or own requests that are in review by someone else
          or_in_and = ["reviews.by_group=#{quote(group.title)}"]

          @relation, inner_or = extend_query_for_involved_reviews(group, or_in_and, @relation, review_states, inner_or)
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
