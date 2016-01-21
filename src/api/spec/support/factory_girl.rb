
RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods

  # build each factory and call #valid? on it
  config.before(:suite) do
    begin
      DatabaseCleaner.start
      FactoryGirl.lint
    ensure
      DatabaseCleaner.clean
    end
  end
end
