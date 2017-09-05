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
          @relation = BsRequest::FindFor::Project.new(@parameters, @relation).all
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
    end
  end
end
