require 'rails_helper'

RSpec.describe Configuration do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_presence_of(:description) }

  it 'creates a new Configuration if no Configuration exists' do
    Configuration.first.destroy
    expect(Configuration.count).to eq(0)
    Configuration.title
    expect(Configuration.count).to eq(1)
  end

  it 'does not create a new Configuration if a Configuration exists ' do
    # The first configuration is created by db/seeds.rb
    expect(Configuration.count).to eq(1)
    Configuration.title
    expect(Configuration.count).to eq(1)
  end

  describe '#delayed_write_to_backend' do
    let(:configuration) { build(:configuration) }

    before do
      allow(Configuration).to receive(:find).and_return(configuration)
      allow(configuration).to receive(:write_to_backend)
    end

    subject! { configuration.delayed_write_to_backend }

    it 'writes to the backend' do
      expect(configuration).to have_received(:write_to_backend)
    end
  end
end
