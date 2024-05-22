module Cloud
  module Azure
    class ConfigurationPolicy < ApplicationPolicy
      def show?
        update?
      end

      def update?
        record.user == user
      end

      def destroy?
        update?
      end
    end
  end
end
