require 'rails_helper'

RSpec.describe Webui::ObsFactory::ApplicationHelper, type: :helper do
  describe '#distribution_tests_link' do
    let(:distribution) { ObsFactory::Distribution.new(create(:project, name: 'openSUSE:Leap:15.1')) }

    it 'creates a url to the openqa distribution tests' do
      expect(distribution_tests_url(distribution)).to eq(
        'https://openqa.opensuse.org/tests/overview?distri=opensuse&version=15'
      )
    end

    context 'when a version is provided' do
      it 'adds the version to the version to the url' do
        expect(distribution_tests_url(distribution, 'my_version')).to eq(
          'https://openqa.opensuse.org/tests/overview?distri=opensuse&version=15&build=my_version'
        )
      end
    end
  end
end
