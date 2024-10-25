class BsRequest
  module FindFor
    class Query < Base
      # rubocop:disable Metrics/PerceivedComplexity
      def all
        @relation = @relation.where(creator: creator) if creator.present?
        @relation = @relation.with_types(types) if types.present?
        @relation = @relation.where(state: states) if states.present?
        @relation = @relation.from_source_project(source_project_name) if source_project_name.present?
        @relation = BsRequest::FindFor::Project.new(@parameters, @relation).all
        @relation = BsRequest::FindFor::User.new(@parameters, @relation).all if user_login.present?
        @relation = @relation.where(creator: user_login) if user_login.present?
        @relation = BsRequest::FindFor::Group.new(@parameters, @relation).all if group_title.present?
        @relation = @relation.in_ids(ids) if @parameters.keys.include?('ids')
        @relation = @relation.do_search(search) if search.present?
        @relation
      end
      # rubocop:enable Metrics/PerceivedComplexity
    end
  end
end
