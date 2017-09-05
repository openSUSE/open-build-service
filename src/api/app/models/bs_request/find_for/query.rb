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
          @relation = extend_query_for_user(user_login, @relation, roles, review_states)
        end
        if group_title.present?
          @relation = extend_query_for_group(group_title, @relation, roles, review_states)
        end
        @relation = @relation.in_ids(@parameters[:ids]) if @parameters[:ids]
        @relation = @relation.do_search(@parameters[:search]) if @parameters[:search].present?
        @relation
      end

      private

      def extend_query_for_group(group, requests, roles, review_states)
        inner_or = []
        group = Group.find_by_title!(group)

        # find requests where group is maintainer in target project
        requests, inner_or = extend_query_for_maintainer(group, requests, roles, inner_or)

        if roles.empty? || roles.include?('reviewer')
          requests = requests.includes(:reviews).references(:reviews)
          # requests where the user is reviewer or own requests that are in review by someone else
          or_in_and = %W(reviews.by_group=#{quote(group.title)})

          requests, inner_or = extend_query_for_involved_reviews(group, or_in_and, requests, review_states, inner_or)
        end
        if inner_or.empty?
          requests.none
        else
          requests.where(inner_or.join(' or '))
        end
      end

      def extend_query_for_user(user, requests, roles, review_states)
        inner_or = []
        user = ::User.find_by_login!(user)

        # user's own submitted requests
        if roles.empty? || roles.include?('creator')
          inner_or << "bs_requests.creator = #{quote(user.login)}"
        end
        # find requests where user is maintainer in target project
        requests, inner_or = extend_query_for_maintainer(user, requests, roles, inner_or)
        if roles.empty? || roles.include?('reviewer')
          requests = requests.includes(:reviews).references(:reviews)

          # requests where the user is reviewer or own requests that are in review by someone else
          or_in_and = %W(reviews.by_user=#{quote(user.login)})

          # include all groups of user
          usergroups = user.groups.map { |group| "'#{group.title}'" }
          or_in_and << "reviews.by_group in (#{usergroups.join(',')})" unless usergroups.blank?

          requests, inner_or = extend_query_for_involved_reviews(user, or_in_and, requests, review_states, inner_or)
        end
        if inner_or.empty?
          requests.none
        else
          requests.where(inner_or.join(' or '))
        end
      end

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
          or_in_and << "reviews.by_project in (#{projects.join(',')})" unless projects.blank?

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
