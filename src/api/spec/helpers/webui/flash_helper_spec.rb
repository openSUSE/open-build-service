require 'rails_helper'

RSpec.describe Webui::FlashHelper do
  describe '#flash_content' do
    let(:flash_with_hash) do
      {
        title: 'example',
        'error 1' => ['error 1 content', 'error 1 content 2'],
        'error 2' => ['error 2 content', 'error 2 content 2']
      }
    end

    let(:result) do
      <<-EOF.strip_heredoc
        <span>example</span>
        <ul>
          <li class='no-bullet'>error 1</li>
          <ul>
            <li>error 1 content</li>
            <li>error 1 content 2</li>
          </ul>
          <li class='no-bullet'>error 2</li>
          <ul>
            <li>error 2 content</li>
            <li>error 2 content 2</li>
          </ul>
        </ul>
       EOF
    end

    let(:flash) { 'example: \\n<i>error 1</i> <b>content</b>' }

    before do
      init_haml_helpers
    end

    it { expect(flash_content(flash_with_hash)).to eq(result) }
    it { expect(flash_content(flash)).to eq('example: error 1 <b>content</b>') }
  end
end
