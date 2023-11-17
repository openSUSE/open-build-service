class WriteAndPreviewComponentPreview < ViewComponent::Preview
  def for_message_editing
    view = ActionView::Base.new('', {}, nil)
    status_message = StatusMessage.new(message: 'Message text', severity: 'announcement', communication_scope: 'in_rollout_users')
    form = ActionView::Helpers::FormBuilder.new(:status_message, status_message, view, {})
    url = '/news_items/preview'
    render(WriteAndPreviewComponent.new(form, url))
  end
end
