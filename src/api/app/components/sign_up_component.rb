# frozen_string_literal: true

class SignUpComponent < ApplicationComponent
  attr_accessor :submit_btn_text

  def initialize(submit_btn_text: 'Sign Up', create_page: false, config: CONFIG)
    super

    @config = config
    @submit_btn_text = sanitize(create_page ? 'Create' : submit_btn_text)
  end

  def proxy_auth_enabled?
    @config['proxy_auth_mode'] == :on
  end

  def proxy_auth_register_page
    @config['proxy_auth_register_page']
  end
end
