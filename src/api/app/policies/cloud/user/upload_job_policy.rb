module Cloud
  module User
    class UploadJobPolicy < ApplicationPolicy
      def show?
        user == record.user || user.staff? || user.admin?
      end

      def destroy?
        show?
      end
    end
  end
end
