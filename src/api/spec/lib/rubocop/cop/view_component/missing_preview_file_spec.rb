require 'rails_helper'
require './lib/rubocop/cop/view_component/missing_preview_file'

RSpec.describe RuboCop::Cop::ViewComponent::MissingPreviewFile, :config do
  let(:config) do
    RuboCop::Config.new({ 'ViewComponent' => { 'Include' => ['app/components/**/*.rb'] } }, '/some/.rubocop.yml')
  end

  context 'when a view component does not have a preview file' do
    it 'registers an offense' do
      expect_offense(<<~RUBY, 'app/components/user_component.rb')
        class UserComponent < ApplicationComponent
        ^ This view component should have a preview file (`src/api/spec/components/previews/user_component_preview.rb`)
          def initialize
            @abc = 'abc'
          end
        end
      RUBY
    end
  end

  context 'when a view component has a preview file' do
    before do
      allow(File).to receive(:exist?).with(Rails.root.join('spec/components/previews/user_component_preview.rb').to_s).and_return(true)
    end

    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY, 'app/components/user_component.rb')
        class UserComponent < ApplicationComponent
          def initialize
            @abc = 'abc'
          end
        end
      RUBY
    end
  end

  context 'when the ApplicationComponent does not have a preview file' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY, 'app/components/application_component.rb')
        class ApplicationComponent
          def initialize
            @abc = 'abc'
          end
        end
      RUBY
    end
  end

  context 'when a file which is not a view component class' do
    it 'does not register an offense' do
      expect_no_offenses(<<~HAML, 'app/components/user_component.html.haml.rb')
        Hello world!
      HAML
    end
  end
end
