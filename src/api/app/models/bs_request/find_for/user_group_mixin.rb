# frozen_string_literal: true
class BsRequest
  module FindFor
    module UserGroupMixin
      private

      def extend_query_for_maintainer(obj, requests, roles, inner_or)
        if roles.empty? || roles.include?('maintainer')
          names = obj.involved_projects.pluck('name').map { |p| quote(p) }
          inner_or << "bs_request_actions.target_project in (#{names.join(',')})" unless names.empty?
          ## find request where group is maintainer in target package, except we have to project already
          obj.involved_packages.includes(:project).pluck('packages.name, projects.name').each do |ip|
            inner_or << "(bs_request_actions.target_project='#{ip.second}' and bs_request_actions.target_package='#{ip.first}')"
          end
        end
        [requests, inner_or]
      end

      def extend_query_for_involved_reviews(obj, or_in_and, requests, review_states, inner_or)
        review_states.each do |review_state|
          # find requests where obj is maintainer in target project
          projects = obj.involved_projects.pluck('projects.name').map { |project| quote(project) }
          or_in_and << "reviews.by_project in (#{projects.join(',')})" if projects.present?

          ## find request where user is maintainer in target package, except we have to project already
          obj.involved_packages.includes(:project).pluck('packages.name, projects.name').each do |ip|
            or_in_and << "(reviews.by_project='#{ip.second}' and reviews.by_package='#{ip.first}')"
          end

          inner_or << "(reviews.state=#{quote(review_state)} and (#{or_in_and.join(' or ')}))"
        end
        [requests, inner_or]
      end
    end
  end
end
