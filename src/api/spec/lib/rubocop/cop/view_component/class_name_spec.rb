require 'rails_helper'
require './lib/rubocop/cop/view_component/class_name'

RSpec.describe RuboCop::Cop::ViewComponent::ClassName, :config do
  let(:config) do
    RuboCop::Config.new({ 'ViewComponent' => { 'Include' => ['app/components/**/*.rb'] } }, '/some/.rubocop.yml')
  end

  context 'when the class name of a view component does not end with "Component"' do
    it 'registers an offense' do
      expect_offense(<<~RUBY, 'app/components/user_avatar_component.rb')
        class UserAvatar < ApplicationComponent
              ^^^^^^^^^^ View component classes must end with `Component`
          def initialize
            @abc = 'abc'
          end
        end
      RUBY
    end
  end

  context 'when the class name of a view component ends with "Component"' do
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

  context 'when the class name of something unrelated to view components does not end with "Component"' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY, 'app/models/package.rb')
        class Package < ApplicationRecord
        end
      RUBY
    end
  end
end
