class BsRequest
  class DataTableRow
    attr_accessor :request
    delegate :created_at, :number, :user, :priority, to: :request

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
