class BsRequest
  module FindFor
    class Group < Base
      include UserGroupMixin

      def all
        maintainer.or(reviewer).with_actions_and_reviews
      end

      private

      def project_ids
        group.involved_projects.pluck(:id)
      end

      def package_ids
        group.involved_packages.pluck(:id)
      end

      def group_ids
        group.id
      end

      def group
        ::Group.find_by_title!(group_title)
      end
    end
  end
end
