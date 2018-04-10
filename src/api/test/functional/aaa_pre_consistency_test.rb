# frozen_string_literal: true
require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_consistency_helper'

class AAAPreConsistency < ActionDispatch::IntegrationTest
  fixtures :all

  def test_resubmit_fixtures
    login_king
    Backend::Test.start(wait_for_scheduler: true)

    ConsistencyCheckJob.new.perform

    resubmit_all_fixtures

    ConsistencyCheckJob.new.perform
  end
end
