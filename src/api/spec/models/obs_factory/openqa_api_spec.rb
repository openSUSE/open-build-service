require 'rails_helper'
require 'webmock/rspec'

RSpec.describe ObsFactory::OpenqaApi do
  let(:openqa_api) { ObsFactory::OpenqaApi.new('https://some_url.com/') }

  describe '::new' do
    it { expect(openqa_api.base_url).to eq('https://some_url.com/api/v1/') }
  end

  describe '#get' do
    context 'when at least one parameter key is empty' do
      it { expect(openqa_api.get('/foo/bar', param1: '1', param2: nil)).to eq({}) }
    end

    context 'when URI is reachable' do
      before do
        stub_request(:get, 'https://some_url.com/foo/bar').and_return(body: %({ "foo": "bar" }), status: 200)
      end

      it 'returns the response decoded as hash' do
        expect(openqa_api.get('/foo/bar')).to eq('foo' => 'bar')
      end
    end

    context 'when URI is redirecting 5 times' do
      let(:openqa_api) { ObsFactory::OpenqaApi.new('https://url_0.com/') }

      before do
        5.times do |n|
          stub_request(:get, "https://url_#{n}.com/foo/bar").and_return(status: 302, headers: { 'location' => "https://url_#{n + 1}.com/foo/bar" })
        end
        stub_request(:get, 'https://url_5.com/foo/bar').and_return(body: %({ "foo": "bar" }), status: 200)
      end

      it 'returns a final response as hash' do
        expect(openqa_api.get('/foo/bar')).to eq('foo' => 'bar')
      end
    end

    context 'when URI is redirecting more than 5 times' do
      let(:openqa_api) { ObsFactory::OpenqaApi.new('https://url_0.com/') }

      before do
        6.times do |n|
          stub_request(:get, "https://url_#{n}.com/foo/bar").and_return(status: 302, headers: { 'location' => "https://url_#{n + 1}.com/foo/bar" })
        end
      end

      it 'returns empty hash' do
        expect(openqa_api.get('/foo/bar')).to eq({})
      end
    end

    context 'when URI is unreachable' do
      before do
        stub_request(:get, 'https://some_url.com/foo/bar').to_return(status: 404)
      end

      it 'returns an empty hash when URI is unreacheable' do
        expect(openqa_api.get('/foo/bar')).to eq({})
      end
    end
  end
end
