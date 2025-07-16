module Webui
  module Packages
    class RpmlintController < Webui::WebuiController
      before_action :set_project
      before_action :set_package
      before_action :set_repository
      before_action :set_architecture

      prepend_before_action :lockout_spiders

      def show
        @rpmlint_log_file = RpmlintLogExtractor.new(project: @project.name, package: @package_name, repository: @repository.name, architecture: @architecture.name).call
        @parsed_messages = RpmlintLogParser.new(content: @rpmlint_log_file).call if @rpmlint_log_file
      end
    end
  end
end
