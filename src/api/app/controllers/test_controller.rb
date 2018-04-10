# frozen_string_literal: true

require 'obsapi/test_sphinx'

class TestController < ApplicationController
  skip_before_action :extract_user
  skip_before_action :require_login

  before_action do
    if Rails.env.test? || Rails.env.development?
      true
    else
      render_error message: 'This is only accessible for testing environments', status: 403
      false
    end
  end

  @@started = false

  # we need a way so the API sings killing me softly
  def killme
    Process.kill('INT', Process.pid)
    @@started = false
    render_ok
  end

  # we need a way so the API uprises fully
  def startme
    if @@started
      render_ok
      return
    end
    @@started = true
    WebMock.disable_net_connect!(allow_localhost: true)
    CONFIG['global_write_through'] = true
    Backend::Api::Server.root
    render_ok
  end
end
