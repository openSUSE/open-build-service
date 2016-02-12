require 'rails_helper'

RSpec.describe Webui::WebuiHelper do
  let(:input) { 'Rocking the Open Build Service' }

  describe '#elide' do
    it 'does not elide' do
      expect(input).to eq(elide(input, input.length))
    end

    it 'does elide 20 character by default in the middle' do
      expect('Rocking t... Service').to eq(elide(input))
    end

    it 'does elide from the left' do
      expect('...the Open Build Service').to eq(elide(input, 25, :left))
    end

    it 'does elide from the right' do
      expect('R...').to eq(elide(input, 4, :right))
    end

    it 'returns three dots for eliding two characters' do
      expect('...').to eq(elide(input, 2, :right))
    end

    it 'returns three dots for eliding three characters' do
      expect('...').to eq(elide(input, 3, :right))
    end

    it 'reduces a string to 10 characters and elides in the middle by default' do
      expect('Rock...ice').to eq(elide(input, 10))
    end
  end

  describe '#elide_two' do
    it 'elides two strings with the proper overall length' do
      input2 = "don't shorten"
      expect([input2, 'Rocking the ...uild Service']).to eq(elide_two(input2, input, 40))
    end
  end

  describe '#valid_xml_id' do
    it 'replaces invalid characters with underscores' do
      expect('a___________').to eq(valid_xml_id('a+&: ./~()@#'))
    end

    it 'prepends an underscore if id does not start with a valid character' do
      expect('_10_2').to eq(valid_xml_id('10.2'))
    end
  end

  describe '#repo_status_icon' do
    it 'renders icon' do
      blocked = repo_status_icon('blocked')
      expect(blocked).to include("icons-time")
      expect(blocked).to include("No build possible atm")
    end

    it 'renders outdated icon' do
      outdated_scheduling = repo_status_icon('outdated_scheduling')
      expect(outdated_scheduling).to include("icons-cog_error")
      expect(outdated_scheduling).to include("state is being calculated")
      expect(outdated_scheduling).to include("needs recalculations")
    end

    it 'renders unknown icon' do
      undefined_icon = repo_status_icon('undefined')
      expect(undefined_icon).to include("icons-eye")
      expect(undefined_icon).to include("Unknown state")
    end
  end
end
