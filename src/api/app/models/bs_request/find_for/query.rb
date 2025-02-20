class BsRequest
  module FindFor
    class Query < Base
      # rubocop:disable Metrics/PerceivedComplexity
      def all
        @relation = @relation.where(creator: creator) if creator.present?
        @relation = @relation.from_project_names(@parameters['project_name']).or(@relation.to_project_names(@parameters['project_name'])) if @parameters['project_name'].present?
        @relation = @relation.with_action_types(types) if types.present?
        @relation = @relation.where(state: states) if states.present?
        @relation = @relation.where(priority: priorities) if priorities.present?
        @relation = @relation.from_project(source_project_name) if source_project_name.present?
        @relation = @relation.joins(:reviews).where('reviews.by_user IN (?) OR reviews.by_group IN (?)', reviewers, reviewers) if reviewers.present?
        @relation = BsRequest::FindFor::Project.new(@parameters, @relation).all
        @relation = BsRequest::FindFor::User.new(@parameters, @relation).all if user_login.present?
        @relation = BsRequest::FindFor::Group.new(@parameters, @relation).all if group_title.present?
        created_at_from = DateTime.parse(@parameters['created_at_from']) if @parameters['created_at_from'].present?
        # [see below] `created_at_to + 1.minute` is a workaround to include the upper limit of the date time range in the filter result set
        created_at_to = DateTime.parse(@parameters['created_at_to']) + 1.minute if @parameters['created_at_to'].present?
        @relation = @relation.where(created_at: (created_at_from..created_at_to))
        @relation = @relation.where(id: ids) if @parameters.key?('ids')
        @relation = @relation.do_search(search) if search.present?
        @relation
      end
      # rubocop:enable Metrics/PerceivedComplexity
    end
  end
end
