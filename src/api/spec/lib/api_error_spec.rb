require 'rails_helper'

RSpec.describe APIError do
  before do
    class MyTestError < APIError; setup('error_foo', 403, 'error foo'); end
  end

  context 'with custom error class' do
    it { expect { raise MyTestError }.to raise_error(MyTestError.new.message) }
    it { expect(MyTestError.new.default_message).to eq('error foo') }
    it { expect(MyTestError.new.status).to eq(403) }
    it { expect(MyTestError.new.errorcode).to eq('error_foo') }
  end

  context 'with custom setup call' do
    before do
      MyTestError.setup('error_bar', 404, 'error bar')
    end

    it { expect(MyTestError.new.default_message).to eq('error bar') }
    it { expect(MyTestError.new.status).to eq(404) }
    it { expect(MyTestError.new.errorcode).to eq('error_bar') }
  end
end
