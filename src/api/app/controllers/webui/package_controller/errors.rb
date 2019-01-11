module Webui::PackageController::Errors
  extend ActiveSupport::Concern

  class CheckPackageNameForNewNotAuthorizedError < Pundit::NotAuthorizedError
    attr_reader :record, :message
    def initialize(record, message)
      @record = record
      @message = message
    end
  end
end
