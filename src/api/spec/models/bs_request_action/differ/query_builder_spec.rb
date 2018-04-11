# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BsRequestAction::Differ::QueryBuilder, vcr: true do
  let!(:user) { create(:confirmed_user, login: 'moi') }
  let!(:source_project) { create(:project, name: 'source_package', maintainer: user) }
  let!(:source_package) { create(:package, name: 'the_package', project: source_project) }
  let!(:another_source_package) { create(:package, name: 'another_source_package', project: source_project) }
  let!(:target_project) { create(:project, name: 'target_project') }
  let!(:target_package) { create(:package, name: 'the_package', project: target_project) }
  let!(:bs_request_action) do
    create(:bs_request_action,
           source_project: source_project,
           source_package: source_package,
           target_project: target_project,
           source_rev: 'revision')
  end
  let!(:bs_request) { create(:bs_request, bs_request_actions: [bs_request_action]) }

  describe '#build' do
    context 'with target package and project' do
      let(:differ) do
        BsRequestAction::Differ::QueryBuilder.new(
          target_project: target_project.name,
          target_package: target_package.name,
          action: bs_request_action,
          source_package: source_package.name
        ).build
      end

      it { expect(differ[:oproject]).to eq('target_project') }
      it { expect(differ[:opackage]).to eq('the_package') }
      it { expect(differ[:expand]).to eq(1) }
      it { expect(differ[:rev]).to eq('revision') }
      it { expect(differ.keys.length).to eq(4) }
    end

    context 'without a target package' do
      let(:differ) do
        BsRequestAction::Differ::QueryBuilder.new(
          target_project: target_project.name,
          action: bs_request_action,
          source_package: source_package.name
        ).build
      end

      it { expect(differ[:opackage]).to eq('the_package') }
      it { expect(differ.keys.length).to eq(4) }
    end

    context 'with a target releaseproject' do
      let!(:release_project) { create(:project, maintainer: user, name: 'release_project_name') }
      let!(:release_package) { create(:package, name: 'the_package', project: release_project) }
      let!(:bs_request_action) do
        create(:bs_request_action,
               source_project: source_project,
               source_package: source_package,
               target_project: target_project,
               target_package: target_package,
               target_releaseproject: release_project.name,
               source_rev: 'revision')
      end
      let!(:bs_request) { create(:bs_request, bs_request_actions: [bs_request_action]) }

      let(:differ) do
        BsRequestAction::Differ::QueryBuilder.new(
          target_project: target_project.name,
          action: bs_request_action,
          source_package: source_package.name
        ).build
      end
      it { expect(differ[:oproject]).to eq('release_project_name') }
      it { expect(differ.keys.length).to eq(4) }
    end

    context 'with a maintenance release target project' do
      let!(:maintenance_release_project) { create(:update_project, name: 'maintenance_project') }
      let!(:maintenance_package) { create(:package, project: maintenance_release_project, name: 'the_package') }

      let(:differ) do
        BsRequestAction::Differ::QueryBuilder.new(
          target_project: maintenance_release_project.name,
          target_package: 'the_package.42',
          action: bs_request_action,
          source_package: source_package.name
        ).build
      end
      it { expect(differ[:oproject]).to eq('maintenance_project') }
      it { expect(differ[:opackage]).to eq('the_package') }
      it { expect(differ.keys.length).to eq(4) }
    end
  end
end
