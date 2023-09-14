# rubocop:disable ViewComponent/MissingPreviewFile
# frozen_string_literal: true

class ReportComponent < ApplicationComponent
  attr_accessor :modal_id, :modal_title

  def initialize(modal_id:, options: {})
    super

    @modal_id = modal_id
    @object_type = options[:object_type]
    @modal_title = options[:modal_title]
    @user = options[:user]
  end

  def confirmation_text
    "Are you sure you want to report this #{@object_type.class.name.downcase}?"
  end

  def render?
    Flipper.enabled?(:content_moderation, @user)
  end
end
# rubocop:enable ViewComponent/MissingPreviewFile
