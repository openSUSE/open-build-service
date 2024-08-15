module FeaturesBento
  def is_bento?
    false
  end

  def skip_unless_bento
    msg = 'The feature tests are executed with BENTO disabled, therefore we skip this test.'
    skip(msg) if is_bento?
  end
end

RSpec.configure do |c|
  c.include FeaturesBento, type: :feature
end
