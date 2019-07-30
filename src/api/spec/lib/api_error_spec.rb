require 'rails_helper'

RSpec.describe APIError do
  let(:api_error_class) do
    Class.new(described_class) do
      setup('error_foo', 403, 'error foo')
    end
  end

  context 'with custom error class' do
    it { expect { raise api_error_class }.to raise_error(api_error_class.new.message) }
    it { expect(api_error_class.new.default_message).to eq('error foo') }
    it { expect(api_error_class.new.status).to eq(403) }
    it { expect(api_error_class.new.errorcode).to eq('error_foo') }
  end

  context 'with custom setup call' do
    before do
      api_error_class.setup('error_bar', 404, 'error bar')
    end

    it { expect(api_error_class.new.default_message).to eq('error bar') }
    it { expect(api_error_class.new.status).to eq(404) }
    it { expect(api_error_class.new.errorcode).to eq('error_bar') }
  end
end
