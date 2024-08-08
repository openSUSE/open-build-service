module Webui
  module Packages
    class ContributionGuideController < WebuiController
      before_action :set_project
      before_action :set_package

      def show
        @contribution_guide_present = @project.text_attachments.find_by(category: :contribution_guide)&.content.present? ||
                                      @package.text_attachments.find_by(category: :contribution_guide)&.content.present?

        @content = (@package.text_attachments.find_by(category: :contribution_guide)&.content.present? ?
                    @package.text_attachments.find_by(category: :contribution_guide)&.content :
                    @project.text_attachments.find_by(category: :contribution_guide)&.content)
       end
    end
  end
end
