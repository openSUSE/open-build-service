require 'rails_helper'

RSpec.describe Workflows::Filter, type: :service do
  describe '#match?' do
    subject { described_class.new(filters: workflow_filters).match?(event) }

    let(:event) { Event::BuildSuccess.create(project: 'openSUSE:Factory', package: 'hello', repository: 'openSUSE_Tumbleweed', arch: 'x86_64', reason: 'foo') }

    context 'architectures' do
      context 'ignore' do
        context 'matching' do
          let(:workflow_filters) do
            { architectures: { ignore: ['ppc'] } }
          end

          it { expect(subject).to be true }
        end

        context 'not matching' do
          let(:workflow_filters) do
            { architectures: { ignore: ['x86_64'] } }
          end

          it { expect(subject).to be false }
        end
      end

      context 'only' do
        context 'matching' do
          let(:workflow_filters) do
            { architectures: { only: ['x86_64'] } }
          end

          it { expect(subject).to be true }
        end

        context 'not matching' do
          let(:workflow_filters) do
            { architectures: { only: ['ppc'] } }
          end

          it { expect(subject).to be false }
        end
      end
    end

    context 'repositories' do
      context 'ignore' do
        context 'matching' do
          let(:workflow_filters) do
            { repositories: { ignore: ['openSUSE_Tumbleweed'] } }
          end

          it { expect(subject).to be false }
        end

        context 'not matching' do
          let(:workflow_filters) do
            { repositories: { ignore: ['CentOS'] } }
          end

          it { expect(subject).to be true }
        end
      end

      context 'only' do
        context 'matching' do
          let(:workflow_filters) do
            { repositories: { only: ['CentOS'] } }
          end

          it { expect(subject).to be false }
        end

        context 'not matching' do
          let(:workflow_filters) do
            { repositories: { only: ['openSUSE_Tumbleweed'] } }
          end

          it { expect(subject).to be true }
        end
      end
    end
  end
end
