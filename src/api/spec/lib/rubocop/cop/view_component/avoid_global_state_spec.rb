require 'rails_helper'
require './lib/rubocop/cop/view_component/avoid_global_state'

RSpec.describe RuboCop::Cop::ViewComponent::AvoidGlobalState, :config do
  context 'when a view component uses params' do
    it 'registers an offense' do
      expect_offense(<<~RUBY)
        class MyComponent < ApplicationComponent
          def initialize
            @abc = params[:abc]
                   ^^^^^^^^^^^^ View components should not rely on global state by using params. Instead, pass the required data to the initialize method.
          end
        end
      RUBY
    end
  end

  context 'when a view component does not use params' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class MyComponent < ApplicationComponent
          def initialize
            @abc = 'abc'
          end
        end
      RUBY
    end
  end

  context 'when a class which is not a view component uses params' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class ClientsController < ApplicationController
          def show
            @client = Client.find(params[:id])
          end
        end
      RUBY
    end
  end
end
