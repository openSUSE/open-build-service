# reset the cache before each test
RSpec.configure do |config|
  config.before do
    Rails.cache.clear
  end
end
