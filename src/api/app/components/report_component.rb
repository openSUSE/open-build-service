# rubocop:disable ViewComponent/MissingPreviewFile
# frozen_string_literal: true

class ReportComponent < ApplicationComponent
  def initialize(options: {})
    super

    @user = options[:user]
  end

  def render?
    Flipper.enabled?(:content_moderation, @user)
  end
end
# rubocop:enable ViewComponent/MissingPreviewFile
