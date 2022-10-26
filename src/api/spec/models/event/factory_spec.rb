require 'rails_helper'

RSpec.describe Event::Factory do
  describe '.new_from_type' do
    subject { described_class.new_from_type(type, params) }

    context 'when the type does not refer to an actual Event class' do
      let(:type) { 'something_wrong' }
      let(:params) { {} }

      it 'does not return an instance of an Event class' do
        expect(subject).to be_nil
      end
    end

    context 'when the type refers to an actual Event class' do
      let(:type) { 'SRCSRV_CREATE_PACKAGE' }
      let(:params) { { 'project' => 'kde4', 'package' => 'kdelibs', 'sender' => 'tom' } }

      it 'returns an instance of the Event class' do
        expect(subject).to be_an_instance_of(Event::CreatePackage)
      end

      it 'sets the attributes of the Event instance' do
        expect(subject).to have_attributes(payload: { 'project' => 'kde4', 'package' => 'kdelibs', 'sender' => 'tom' })
      end
    end
  end
end
