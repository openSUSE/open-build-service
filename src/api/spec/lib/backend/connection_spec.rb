# spec/lib/backend/connection_spec.rb

RSpec.describe Backend::Connection do
  let(:host) { 'localhost' }
  let(:port) { 5352 }

  before do
    allow(described_class).to receive_messages(host: host, port: port)
  end

  describe '.get' do
    context 'when the backend is unreachable' do
      before do
        allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED)
      end

      it 'raises a Backend::Error' do
        expect { described_class.get('/foo') }.to raise_error(Backend::Error, /Backend unreachable/)
      end
    end
  end

  describe '.put' do
    context 'when the backend is unreachable' do
      before do
        allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED)
      end

      it 'raises a Backend::Error' do
        expect { described_class.put('/foo', 'data') }.to raise_error(Backend::Error, /Backend unreachable/)
      end
    end
  end

  describe '.delete' do
    context 'when the backend is unreachable' do
      before do
        allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED)
      end

      it 'raises a Backend::Error' do
        expect { described_class.delete('/foo') }.to raise_error(Backend::Error, /Backend unreachable/)
      end
    end
  end
end
