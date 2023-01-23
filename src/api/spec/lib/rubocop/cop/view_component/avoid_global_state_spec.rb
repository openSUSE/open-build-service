require 'rails_helper'
require './lib/rubocop/cop/view_component/avoid_global_state'

RSpec.describe RuboCop::Cop::ViewComponent::AvoidGlobalState, :config do
  let(:config) do
    RuboCop::Config.new({ 'ViewComponent' => { 'Include' => ['app/components/**/*.rb'] } }, '/some/.rubocop.yml')
  end

  context 'when a view component uses params or calls a User class method' do
    it 'registers an offense' do
      expect_offense(<<~RUBY, 'app/components/my_component.rb')
        class MyComponent < ApplicationComponent
          def initialize
            @abc = params[:abc]
                   ^^^^^^^^^^^^ View components should not rely on global state by using params[:abc]. Instead, pass the required data to the initialize method.
            @abc_def = params[:abc][:def]
                       ^^^^^^^^^^^^ View components should not rely on global state by using params[:abc]. Instead, pass the required data to the initialize method.
            @def = User.session
                   ^^^^^^^^^^^^ View components should not rely on global state by calling User.session. Instead, pass the required data to the initialize method.
            @aaa = User.find_by(login: 'someone')
                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ View components should not rely on global state by calling User.find_by(login: 'someone'). Instead, pass the required data to the initialize method.

          end
        end
      RUBY
    end
  end

  context 'when a view component does not use params and does not call a User class method' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY, 'app/components/my_component.rb')
        class MyComponent < ApplicationComponent
          def initialize
            @abc = 'abc'
          end
        end
      RUBY
    end
  end

  context 'when a class which is not a view component uses params or calls a User class method' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY, 'app/controllers/clients_controller.rb')
        class ClientsController < ApplicationController
          def show
            @user = User.session
            @client = Client.find(params[:id])
          end
        end
      RUBY
    end
  end
end
