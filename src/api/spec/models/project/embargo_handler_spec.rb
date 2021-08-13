require 'rails_helper'

RSpec.describe 'Project::EmbargoHandler' do
  let!(:user) { create(:confirmed_user, login: 'bar') }
  let!(:project) { create(:project, name: 'foo', maintainer: user) }
  let(:attrib) { create(:embargo_date_attrib, project: project) }

  let(:embargo_handler) { Project::EmbargoHandler.new(project) }

  before do
    login user
    attrib
  end

  describe '#call' do
    let(:attrib_value) { instance_double(AttribValue) }

    context 'Project is embargoed' do
      it { expect { embargo_handler.call }.to raise_error BsRequest::Errors::UnderEmbargo }
    end

    context 'Embargo is in the past' do
      before do
        allow(attrib_value).to receive(:value).and_return((Time.now.utc - 2.days).to_s)
        allow(embargo_handler).to receive(:embargo_date_attribute).and_return(attrib_value)
      end

      it { expect { embargo_handler.call }.not_to raise_error }
    end

    context 'Embargo is invalid' do
      before do
        allow(attrib_value).to receive(:value).and_return('batatinha')
        allow(embargo_handler).to receive(:embargo_date_attribute).and_return(attrib_value)
      end

      it { expect { embargo_handler.call }.to raise_error(BsRequest::Errors::InvalidDate) }
    end
  end
end
