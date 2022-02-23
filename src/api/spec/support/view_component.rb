require 'view_component/test_helpers'
# To write view component specs with Capybara matchers
require 'capybara/rspec'

# For context, see https://github.com/github/view_component/issues/1288
module ViewComponentTestHelpersRenderInline
  include ViewComponent::TestHelpers

  def render_inline(component, allowed_queries: 0)
    expect { super(component) }.to make_database_queries(count: allowed_queries)

    rendered_component # from ViewComponent::TestHelpers
  end
end

RSpec.configure do |config|
  config.include ViewComponentTestHelpersRenderInline, type: :component
  config.include Capybara::RSpecMatchers, type: :component
end
