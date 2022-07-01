require 'rails_helper'

RSpec.describe 'Project::EmbargoHandler' do
  let(:user) { create(:confirmed_user, login: 'bar') }
  let(:project) { create(:project, name: 'foo', maintainer: user) }
  let(:attrib) { create(:embargo_date_attrib, project: project, values: [attrib_value]) }

  subject { Project::EmbargoHandler.new(project).call }

  before do
    login user
    attrib
  end

  describe '#call' do
    context 'Project is embargoed' do
      let(:attrib) { create(:embargo_date_attrib, project: project) }

      it { expect { subject }.to raise_error BsRequest::Errors::UnderEmbargo }
    end

    context 'Embargo is an empty string' do
      let(:attrib_value) { create(:attrib_value, value: '') }

      it { expect { subject }.to raise_error(BsRequest::Errors::InvalidDate) }
    end

    context 'Embargo is in the past' do
      let(:attrib_value) { create(:attrib_value, value: (Time.now.utc - 2.days).to_s) }

      it { expect { subject }.not_to raise_error }
    end

    context 'Embargo is invalid' do
      let(:attrib_value) { create(:attrib_value, value: 'batatinha') }
      let(:attrib) { build(:embargo_date_attrib, project: project, values: [attrib_value]).save(validate: false) }

      it { expect { subject }.to raise_error(BsRequest::Errors::InvalidDate) }
    end

    context 'Embargo has an invalid timezone' do
      let(:attrib_value) { create(:attrib_value, value: '2022-01-01 01:01:01 invalid_timezone') }
      let(:attrib) { build(:embargo_date_attrib, project: project, values: [attrib_value]).save(validate: false) }

      it { expect { subject }.to raise_error(BsRequest::Errors::InvalidDate) }
    end

    context 'Embargo is valid (with timezone)' do
      let(:attrib_value) { create(:attrib_value, value: '2022-01-01 01:01:01 CET') }

      it { expect { subject }.not_to raise_error }
    end
  end
end
