module BentoDetection
  def is_bento?
    ENV['BENTO'].present?
  end

  def skip_unless_bento
    msg = 'BENTO theme specific behavior and bento is disabled, skipping.'
    skip(msg) if ENV['BENTO'].blank?
  end
end

RSpec.configure do |c|
  c.include BentoDetection, type: :feature
  c.include BentoDetection, type: :controller
end
