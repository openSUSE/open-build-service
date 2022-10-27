module Webui
  module Packages
    class BadgeController < Packages::MainController
      before_action :set_project
      before_action :set_package

      def show
        results = @package.buildresult(@project, false, true).results[@package.name]
        results = results.select { |r| r.architecture == params[:architecture] } if params[:architecture]
        results = results.select { |r| r.repository == params[:repository] } if params[:repository]
        send_data(create_badge(results), type: 'image/svg+xml', disposition: 'inline')
      end

      private

      def create_badge(results)
        filename = 'badge-unknown.svg'
        return Rails.application.assets[filename].source if results.blank?

        filename = 'badge-failed.svg' if results.any? { |r| r.code == 'failed' }
        filename = 'badge-succeeded.svg' if results.all? { |r| r.code == 'succeeded' }
        filename = 'badge-percent.svg' if params[:type] == 'percent'
        get_badge_file(filename, results)
      end

      def get_badge_file(filename, results)
        file = Rails.application.assets[filename].source
        return file unless params[:type] == 'percent'

        succeeded = results.select { |r| r.code == 'succeeded' }.try(:length).to_i
        file.gsub!('#e05d44', '#4c1') if succeeded == results.length
        file.gsub('%PERCENTAGE%', "#{100 * succeeded / results.length}%")
      end
    end
  end
end
