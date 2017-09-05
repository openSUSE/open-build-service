class BsRequest
  module FindFor
    class User < Base
      include UserGroupMixin

      def all
        maintainer.or(reviewer.or(creator)).with_actions_and_reviews
      end

      private

      def creator
        if roles.blank? || roles.include?('creator')
          BsRequest.where(creator: user.login)
        else
          BsRequest.none
        end
      end

      def reviewer
        if roles.blank? || roles.include?('reviewer')
          super.or(BsRequest.where(id: Review.bs_request_ids_of_involved_users(user.id).where(state: review_states)))
        else
          BsRequest.none
        end
      end

      def project_ids
        user.involved_projects.pluck(:id)
      end

      def package_ids
        user.involved_packages.pluck(:id)
      end

      def group_ids
        user.groups.pluck(:id)
      end

      def user
        ::User.find_by_login!(user_login)
      end
    end
  end
end
