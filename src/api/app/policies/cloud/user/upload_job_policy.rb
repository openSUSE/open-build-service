module Cloud
  module User
    class UploadJobPolicy < ApplicationPolicy
      def show?
        @user == @record.user || @user.is_staff? || @user.is_admin?
      end

      def destroy?
        show?
      end
    end
  end
end
