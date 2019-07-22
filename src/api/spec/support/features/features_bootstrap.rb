# typed: false
module FeaturesBootstrap
  def is_bootstrap?
    ENV['BOOTSTRAP'].present?
  end

  def skip_if_bootstrap
    msg = 'The feature tests are executed with BOOTSTRAP enabled, therefore we skip this test.'
    skip(msg) if ENV['BOOTSTRAP'].present?
  end
end

RSpec.configure do |c|
  c.include FeaturesBootstrap, type: :feature
end
