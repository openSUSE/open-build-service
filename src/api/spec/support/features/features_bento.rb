module FeaturesBento
  def is_bento?
    ENV['BENTO'].present?
  end

  def skip_unless_bento
    msg = 'The feature tests are executed with BENTO disabled, therefore we skip this test.'
    skip(msg) if ENV['BENTO'].blank?
  end
end

RSpec.configure do |c|
  c.include FeaturesBento, type: :feature
end
