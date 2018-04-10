# frozen_string_literal: true
require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class StatusMessageTest < ActiveSupport::TestCase
  fixtures :users

  def test_something
    sm = StatusMessage.new message: 'nothing is here', severity: 2
    sm.user = User.find_by_login 'tom'
    sm.save!
  end

  def test_delete
    tbd = StatusMessage.create! message: 'to be deleted', user: User.find_by_login('tom'), severity: 1
    # tbd.user = User.find_by_login 'tom'
    tbd.delete

    findit = StatusMessage.find_by_id tbd.id
    assert_equal tbd.id, findit.id
    assert_equal true, findit.deleted_at > Time.now - 1.day
  end
end
