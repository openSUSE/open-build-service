class BsRequest
  module FindFor
    module UserGroupMixin
      private

      # BsRequestsActions where obj (group or user) is maintainer in target project
      def bs_request_actions(obj)
        query_string = 'target_project IN (?)'
        query_string += " OR ((target_project, target_package) IN (#{packages_query(obj)}))" if packages_query(obj).present?
        BsRequestAction.where(query_string, projects(obj))
      end

      # Reviews where obj (group or user) is reviewer in tarjet project
      def reviews(obj, review_states)
        query_string = "by_#{obj.class.name.downcase} = ? OR by_project IN (?)"
        query_string += " OR by_group IN (#{usergroups_query(obj)})" if obj.is_a?(::User) && usergroups_query(obj).present?
        query_string += " OR ((by_project, by_package) IN (#{packages_query(obj)}))" if packages_query(obj).present?

        Review.where(state: review_states)
              .where(query_string, obj.to_s, projects(obj))
      end

      def projects(obj)
        @projects ||= obj.involved_projects.pluck('projects.name')
      end

      def usergroups_query(obj)
        @usergroups_query ||= obj.groups.pluck(:title).map { |group| quote(group) }.join(',')
      end

      def packages_query(obj)
        return @packages_query if @packages_query

        # Hoping that Rails allows to write this nicer: https://github.com/rails/rails/issues/35925
        projects_and_packages = obj.involved_packages.includes(:project).pluck('projects.name', 'packages.name')
        @packages_query = projects_and_packages.map { |project, package| "(#{quote(project)},#{quote(package)})" }.join(',')
      end
    end
  end
end
