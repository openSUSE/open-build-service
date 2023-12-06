# frozen_string_literal: true

class SignUpComponent < ApplicationComponent
  attr_accessor :submit_btn_text

  def initialize(submit_btn_text: 'Sign Up', create_page: false)
    super

    @submit_btn_text = sanitize(create_page ? 'Create' : submit_btn_text)
  end

  def proxy_auth_mode_enabled?
    ::Configuration.proxy_auth_mode_enabled?
  end

  def proxy_auth_register_page
    CONFIG['proxy_auth_register_page']
  end
end
