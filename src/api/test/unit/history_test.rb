# frozen_string_literal: true

require_relative '../test_helper'

class HistoryTest < ActionMailer::TestCase
  fixtures :all

  test 'basic operation request creations' do
    req = BsRequest.first
    user = User.first
    a = HistoryElement::RequestAccepted.create(request: req, comment: 'yxc', user_id: user.id)
    s = HistoryElement::RequestSuperseded.create(request: req, description_extension: '42', comment: 'I like it better', user_id: user.id)

    assert_equal a.request.class, BsRequest
    assert_equal a.description, 'Request got accepted' # overwrite must not work
    assert_equal a.comment, 'yxc'

    assert_equal s.request.class, BsRequest
    assert_equal s.description, 'Request got superseded by request 42' # overwrite must not work
    assert_equal s.comment, 'I like it better'

    list = req.request_history_elements
    assert_equal list.length, 2
  end
end
