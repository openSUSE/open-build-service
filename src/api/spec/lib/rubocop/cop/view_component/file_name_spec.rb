require 'rails_helper'
require './lib/rubocop/cop/view_component/file_name'

RSpec.describe RuboCop::Cop::ViewComponent::FileName, :config do
  let(:config) do
    RuboCop::Config.new({ 'ViewComponent' => { 'Include' => ['app/components/**/*.rb'] } }, '/some/.rubocop.yml')
  end

  context 'when the file name of a view component does not end with "_component.rb"' do
    it 'registers an offense' do
      expect_offense(<<~RUBY, 'app/components/user_avatar.rb')
        class UserAvatar < ApplicationComponent
        ^ The name of the source file (`user_avatar.rb`) should end with `_component.rb`
          def initialize
            @abc = 'abc'
          end
        end
      RUBY
    end
  end

  context 'when the file name of a view component ends with "_component.rb"' do
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

  context 'when the file name of something unrelated to view components does not end with "_component.rb"' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY, 'app/models/package.rb')
        class Package < ApplicationRecord
        end
      RUBY
    end
  end
end
