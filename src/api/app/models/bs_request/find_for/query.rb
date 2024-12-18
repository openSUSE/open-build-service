class BsRequest
  module FindFor
    class Query < Base
      # rubocop:disable Metrics/PerceivedComplexity
      def all
        @relation = @relation.where(creator: creator) if creator.present?
        @relation = @relation.with_action_types(types) if types.present?
        @relation = @relation.where(state: states) if states.present?
        @relation = @relation.from_project(source_project_name) if source_project_name.present?
        @relation = BsRequest::FindFor::Project.new(@parameters, @relation).all
        @relation = BsRequest::FindFor::User.new(@parameters, @relation).all if user_login.present?
        @relation = BsRequest::FindFor::Group.new(@parameters, @relation).all if group_title.present?
        created_at_from = Date.parse(@parameters['created_at_from']) if @parameters['created_at_from'].present?
        created_at_to = Date.parse(@parameters['created_at_to']) if @parameters['created_at_to'].present?
        @relation = @relation.where(created_at: (created_at_from&.beginning_of_day..created_at_to&.end_of_day))
        @relation = @relation.where(id: ids) if @parameters.key?('ids')
        @relation = @relation.do_search(search) if search.present?
        @relation
      end
      # rubocop:enable Metrics/PerceivedComplexity
    end
  end
end
