module Webui
  module Packages
    class BadgeController < Webui::WebuiController
      before_action :set_project
      before_action :set_package

      def show
        results = @package.buildresult(@project, show_all: false, lastbuild: true).results[@package.name]
        results = results.select { |r| r.architecture == params[:architecture] } if params[:architecture]
        results = results.select { |r| r.repository == params[:repository] } if params[:repository]
        results = discard_non_relevant_results(results) unless results.nil?
        badge = Badge.new(params[:type], results)
        send_data(badge.xml, type: 'image/svg+xml', disposition: 'inline')
      end

      # discard results with excluded and disabled status
      # discard disabled with possible previous failed results
      def discard_non_relevant_results(results)
        results.reject { |r| Buildresult.new(r.code).refused_status? || @package.disabled_for?('build', r.repository, r.architecture) }
      end
    end
  end
end
