require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Package, vcr: true do
  let(:admin) { create(:admin_user) }
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:home_project) { user.home_project }
  let(:package) { create(:package, name: 'test_package', project: home_project) }
  let(:services) { package.services }

  context '#save_file' do
    before do
      User.current = user
    end

    it 'calls #addKiwiImport if filename ends with kiwi.txz' do
      Service.any_instance.expects(:addKiwiImport).once
      package.save_file({ filename: 'foo.kiwi.txz' })
    end

    it 'does not call #addKiwiImport if filename ends not with kiwi.txz' do
      Service.any_instance.expects(:addKiwiImport).never
      package.save_file({ filename: 'foo.spec' })
    end
  end

  context "is_admin?" do
    it "returns true for admins" do
      expect(admin.is_admin?).to be true
    end

    it "returns false for non-admins" do
      expect(user.is_admin?).to be false
    end
  end

  context '#delete_file' do
    let(:package_with_file) { create(:package_with_file, name: 'package_with_files', project: home_project)}
    let(:url) { "http://localhost:3200/source/#{home_project.name}/#{package_with_file.name}" }

    before do
      User.current = user
    end

    context 'with delete permission' do
      context 'with default options' do
        before do
          package_with_file.delete_file('somefile.txt')
        end

        it 'deletes file' do
          expect {
            package_with_file.source_file('somefile.txt')
          }.to raise_error(ActiveXML::Transport::NotFoundError)
        end

        it 'sets options correct' do
          expect(a_request(:delete, "#{url}/somefile.txt?user=#{user.login}")).to have_been_made.once
        end
      end

      context 'with custom options' do
        before do
          package_with_file.delete_file('somefile.txt', { comment: 'comment' })
        end

        it 'sets options correct' do
          expect(a_request(:delete, "#{url}/somefile.txt?comment=comment&user=#{user.login}")).to have_been_made.once
        end
      end
    end

    context 'with no delete permission' do
      let(:other_user) { create(:user) }

      before do
        User.current = other_user
      end

      it 'raises DeleteFileNoPermission exception' do
        expect {
          package_with_file.delete_file('somefile.txt')
        }.to raise_error(DeleteFileNoPermission)
      end

      it 'does not delete file' do
        expect {
          package_with_file.source_file('somefile.txt')
        }.to_not raise_error
      end
    end

    context 'file not found' do
      it 'raises NotFoundError' do
        expect {
          package_with_file.source_file('not_existent.txt')
        }.to raise_error(ActiveXML::Transport::NotFoundError)
      end
    end
  end
end
