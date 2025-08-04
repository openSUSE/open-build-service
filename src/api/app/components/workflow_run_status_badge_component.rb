class WorkflowRunStatusBadgeComponent < ApplicationComponent
  def initialize(status:, css_class: nil)
    super

    @status = status
    @css_class = css_class
  end

  def call
    content_tag(
      :span,
      tag.i(class: "fas fa-#{decode_status_icon} me-1").concat(@status),
      class: ['badge', "text-bg-#{decode_status_color}", @css_class]
    )
  end

  private

  def decode_status_color
    case @status
    when 'fail'
      'danger'
    else
      'dark'
    end
  end

  def decode_status_icon
    case @status
    when 'fail'
      'exclamation-triangle'
    else
      'book-open'
    end
  end
end
