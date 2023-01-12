module Cloud
  module Azure
    class ConfigurationPolicy < ApplicationPolicy
      def initialize(user, record, opts = {})
        super(user, record, { ensure_logged_in: true }.merge(opts))
      end

      def show?
        record_of_user?
      end

      def update?
        record_of_user?
      end

      def destroy?
        record_of_user?
      end

      private

      def record_of_user?
        record.user == user
      end
    end
  end
end
