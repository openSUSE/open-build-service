module SphinxHelpers
  def thinking_sphinx_test_init
    ThinkingSphinx::Test.init
    ThinkingSphinx::Test.start index: false
    ThinkingSphinx::Configuration.instance.settings['real_time_callbacks'] = true
  end

  def thinking_sphinx_test_stop
    ThinkingSphinx::Test.stop
    ThinkingSphinx::Test.clear
    ThinkingSphinx::Configuration.instance.settings['real_time_callbacks'] = false
  end
end

RSpec.configure do |config|
  config.include SphinxHelpers, :thinking_sphinx

  config.before(:context, :thinking_sphinx) do
    thinking_sphinx_test_init
  end

  config.after(:context, :thinking_sphinx) do
    thinking_sphinx_test_stop
  end
end
