class BsRequest
  module FindFor
    class Query < Base
      def initialize(parameters, relation = BsRequest.with_actions_and_reviews)
        super
        @relation = @relation.with_types(types) if types.present?
        @relation = @relation.in_states(states) if states.present?
      end

      def all
        if source_project_name.present?
          @relation = @relation.from_source_project(source_project_name)
        end
        if project_name.present?
          @relation = extend_query_for_project(@relation, roles, states, review_states, package_name, subprojects, project_name)
        end
        if user_login.present?
          @relation = BsRequest::FindFor::User.new(@parameters, @relation).all
        end
        if group_title.present?
          @relation = BsRequest::FindFor::Group.new(@parameters, @relation).all
        end
        @relation = @relation.in_ids(@parameters[:ids]) if @parameters[:ids]
        @relation = @relation.do_search(@parameters[:search]) if @parameters[:search].present?
        @relation
      end

      private

      def extend_query_for_project(requests, roles, states, review_states, package, subprojects, project)
        inner_or = []
        requests, inner_or = extend_relation('source', requests, roles, package, subprojects, project, inner_or)
        requests, inner_or = extend_relation('target', requests, roles, package, subprojects, project, inner_or)

        if (roles.empty? || roles.include?('reviewer')) &&
            (states.empty? || states.include?('review'))
          requests = requests.references(:reviews)
          review_states.each do |review_state|
            requests = requests.includes(:reviews)
            if package.blank?
              inner_or << "(reviews.state=#{quote(review_state)} and reviews.by_project=#{quote(project)})"
            else
              inner_or << "(reviews.state=#{quote(review_state)} and reviews.by_project=#{quote(project)} and reviews.by_package=#{quote(package)})"
            end
          end
        end
        if inner_or.empty?
          requests.none
        else
          requests.where(inner_or.join(' or '))
        end
      end

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
