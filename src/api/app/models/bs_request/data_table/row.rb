# frozen_string_literal: true
class BsRequest
  module DataTable
    class Row
      attr_accessor :request
      delegate :updated_at, :id, :created_at, :number, :creator, :priority, to: :request

      def initialize(request)
        @request = request
      end

      def source_package
        cache[:source_package]
      end

      def source_project
        cache[:source_project]
      end

      def request_type
        cache[:request_type]
      end

      def target_package_id
        cache[:target_package_id]
      end

      def target_project
        cache[:target_project]
      end

      def target_package
        cache[:target_package]
      end

      private

      def cache
        @cache ||= ApplicationController.helpers.common_parts(request)
      end
    end
  end
end
