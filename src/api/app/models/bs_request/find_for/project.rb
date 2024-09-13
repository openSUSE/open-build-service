class BsRequest
  module FindFor
    class Project < Base
      def all
        return @relation unless project_name.present? || package_name.present?

        @where_conditions = []
        @where_values = []

        bs_request_actions_conditions('source')
        bs_request_actions_conditions('target')

        reviews_conditions

        @relation = @relation.where("(#{@where_conditions.join(') or (')})", *@where_values.flatten) if @where_conditions.present?
        @relation
      end

      private

      def bs_request_actions_conditions(source_or_target)
        return unless roles.empty? || roles.include?(source_or_target)

        bs_request_actions_filters = []
        if project_name.present?
          bs_request_actions_filters << if subprojects.blank?
                                          ["bs_request_actions.#{source_or_target}_project = ?", project_name]
                                        else
                                          ["bs_request_actions.#{source_or_target}_project like ?", "#{project_name}:%"]
                                        end
        end
        bs_request_actions_filters << ["bs_request_actions.#{source_or_target}_package = ?", package_name] if package_name.present?

        @where_conditions << bs_request_actions_filters.pluck(0).join(' and ')
        @where_values << bs_request_actions_filters.pluck(1)
      end

      def fill_reviews_filters(review_state)
        filters = [['reviews.state = ?', review_state]]
        filters << ['reviews.by_project = ?', project_name] if project_name.present?
        filters << ['reviews.by_package = ?', package_name] if package_name.present?

        filters
      end

      def reviews_conditions
        return unless (roles.empty? || roles.include?('reviewer')) && (states.empty? || states.include?('review'))

        @relation = @relation.references(:reviews).includes(:reviews)
        review_states.each do |review_state|
          reviews_filters = fill_reviews_filters(review_state)

          @where_conditions << reviews_filters.pluck(0).join(' and ')
          @where_values << reviews_filters.pluck(1)
        end
      end
    end
  end
end
