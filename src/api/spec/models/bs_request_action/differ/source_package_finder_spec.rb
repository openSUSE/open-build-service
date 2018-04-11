# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BsRequestAction::Differ::SourcePackageFinder do
  let!(:user) { create(:confirmed_user, login: 'moi') }
  let!(:source_project) { create(:project, maintainer: user) }
  let!(:source_package) { create(:package, name: 'source_package', project: source_project) }
  let!(:another_source_package) { create(:package, name: 'another_source_package', project: source_project) }
  let!(:target_project) { create(:project) }

  describe '#all' do
    context 'with a source package' do
      let!(:bs_request) do
        create(:bs_request_with_submit_action,
               source_project: source_project,
               source_package: source_package,
               target_project: target_project)
      end
      let!(:bs_request_action) { bs_request.bs_request_actions.first }
      let!(:finder) { BsRequestAction::Differ::SourcePackageFinder.new(bs_request_action: bs_request_action) }

      context 'and source access' do
        it { expect(finder.all).to eq(['source_package']) }
      end

      context 'and without source access' do
        before do
          create(:sourceaccess_flag, project: source_project)
          login(user)
        end

        it { expect { finder.all }.to raise_error(Package::ReadSourceAccessError) }
      end

      context 'and an BsRequestAcceptInfo' do
        before do
          BsRequestActionAcceptInfo.create(bs_request_action: bs_request_action)
        end

        it { expect(finder.all).to eq(['source_package']) }
      end
    end

    context 'without a source package but a source project' do
      let(:bs_request) do
        create(:bs_request_with_maintenance_incident_action,
               source_project: source_project,
               target_project: target_project)
      end
      let!(:bs_request_action) { bs_request.bs_request_actions.first }
      let!(:finder) { BsRequestAction::Differ::SourcePackageFinder.new(bs_request_action: bs_request_action) }
      context 'and source access' do
        it { expect(finder.all).to eq(['another_source_package', 'source_package']) }
      end

      context 'and without source access' do
        before do
          create(:sourceaccess_flag, project: source_project)
          login(user)
        end

        it { expect { finder.all }.to raise_error(Package::ReadSourceAccessError) }
      end
    end
  end
end
