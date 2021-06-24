class BsRequest
  module FindFor
    class Query < Base
      def all
        @relation = @relation.with_types(types) if types.present?
        @relation = @relation.in_states(states) if states.present?
        @relation = @relation.from_source_project(source_project_name) if source_project_name.present?
        @relation = BsRequest::FindFor::Project.new(@parameters, @relation).all if project_name.present?
        @relation = BsRequest::FindFor::User.new(@parameters, @relation).all if user_login.present?
        @relation = BsRequest::FindFor::Group.new(@parameters, @relation).all if group_title.present?
        @relation = @relation.in_ids(ids) if ids.present?
        @relation = @relation.do_search(search) if search.present?
        @relation
      end
    end
  end
end
