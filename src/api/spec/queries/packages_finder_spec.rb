require 'rails_helper'

RSpec.describe PackagesFinder, vcr: true do
  describe '#by_package_and_project' do
    let(:project) { create(:project, name: 'foo') }
    let!(:package) { create(:package, name: 'foo_pack', project: project) }

    context 'package and project exist' do
      subject { PackagesFinder.new.by_package_and_project(package.name, project.name) }

      it { expect(subject).not_to be_empty }
    end

    context 'package or project doesn\'t exist' do
      subject { PackagesFinder.new.by_package_and_project('foo_pack', 'fooa') }

      it { expect(subject).to be_empty }
    end
  end

  describe '#find_by_attribute_type' do
    let(:admin_user) { create(:admin_user, login: 'superbad') }
    let(:project) { create(:project, name: 'foo') }
    let!(:package) { create(:package, name: 'foo_pack', project: project) }
    let(:maintained_attrib) { create(:maintained_attrib, project: project, package: package) }

    context 'when package is nil' do
      before do
        User.session = admin_user
      end

      subject { PackagesFinder.new.find_by_attribute_type(maintained_attrib.attrib_type) }

      it { expect(subject).not_to be_empty }
    end

    context 'when package is valid' do
      before do
        User.session = admin_user
      end

      subject { PackagesFinder.new.find_by_attribute_type(maintained_attrib.attrib_type, package.name) }

      it { expect(subject).not_to be_empty }
    end

    context 'when package is invalid' do
      before do
        User.session = admin_user
      end

      subject { PackagesFinder.new.find_by_attribute_type(maintained_attrib.attrib_type, 'xoo') }

      it { expect(subject).to be_empty }
    end
  end

  describe 'find_by_attribute_type_and_value' do
    let(:admin_user) { create(:admin_user, login: 'superbad') }
    let(:project) { create(:project, name: 'foo') }
    let!(:package) { create(:package, name: 'foo_pack', project: project) }
    let!(:embargo_date_attrib_type) do
      AttribType.create(name: 'EmbargoDate',
                        attrib_namespace: AttribNamespace.find_by!(name: 'OBS'), value_count: 1)
    end
    let(:embargo_date_attrib) { create(:embargo_date_attrib, project: project, package: package) }

    context 'when package is nil' do
      before do
        User.session = admin_user
      end

      subject { PackagesFinder.new.find_by_attribute_type_and_value(embargo_date_attrib.attrib_type, '2021-11-11') }

      it { expect(subject).not_to be_empty }
      it { expect(subject).to include(package) }
    end
  end
end
