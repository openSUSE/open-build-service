class BsRequest
  module FindFor
    module UserGroupMixin
      private

      def maintainer
        if roles.blank? || roles.include?('maintainer')
          BsRequest.where(id: BsRequestAction.bs_request_ids_of_involved_projects(project_ids).or(
            BsRequestAction.bs_request_ids_of_involved_packages(package_ids)))
        else
          BsRequest.none
        end
      end

      def reviewer
        if roles.blank? || roles.include?('reviewer')
          review_ids = Review.bs_request_ids_of_involved_projects(project_ids).or(
            Review.bs_request_ids_of_involved_packages(package_ids).or(
              Review.bs_request_ids_of_involved_groups(group_ids)
            )
          ).where(state: review_states)
          BsRequest.where(id: review_ids)
        else
          BsRequest.none
        end
      end
    end
  end
end
