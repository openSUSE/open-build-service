class BsRequest
  module FindFor
    class Project < Base
      def all
        inner_or = []
        @relation, inner_or = extend_relation('source', @relation, roles, package_name, subprojects, project_name, inner_or)
        @relation, inner_or = extend_relation('target', @relation, roles, package_name, subprojects, project_name, inner_or)

        if (roles.empty? || roles.include?('reviewer')) &&
           (states.empty? || states.include?('review'))
          @relation = @relation.references(:reviews)
          review_states.each do |review_state|
            @relation = @relation.includes(:reviews)
            if project_name.blank?
              inner_or << "(reviews.state=#{quote(review_state)} and reviews.by_project=#{quote(project_name)})"
            else
              inner_or <<
                "(reviews.state=#{quote(review_state)} and reviews.by_project=#{quote(project_name)} and reviews.by_package=#{quote(package_name)})"
            end
          end
        end
        if inner_or.empty?
          @relation.none
        else
          @relation.where(inner_or.join(' or '))
        end
      end

      private

      def extend_relation(source_or_target, requests, roles, package, subprojects, project, inner_or)
        if roles.empty? || roles.include?(source_or_target)
          if package.blank?
            if subprojects.blank?
              inner_or << "bs_request_actions.#{source_or_target}_project=#{quote(project)}"
            else
              inner_or << "(bs_request_actions.#{source_or_target}_project like #{quote(project + ':%')})"
            end
          else
            inner_or << "(bs_request_actions.#{source_or_target}_project=#{quote(project)} and " +
                        "bs_request_actions.#{source_or_target}_package=#{quote(package)})"
          end
        end
        [requests, inner_or]
      end
    end
  end
end
