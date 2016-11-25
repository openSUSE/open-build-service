require 'rails_helper'
require 'webmock/rspec'
# WARNING: If you change #file_exists or #has_file test make sure
# you uncomment the next line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe Package, vcr: true do
  let(:admin) { create(:admin_user) }
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:home_project) { user.home_project }
  let(:package) { create(:package, name: 'test_package', project: home_project) }
  let(:package_with_file) { create(:package_with_file, name: 'package_with_files', project: home_project) }
  let(:services) { package.services }
  let(:group_bugowner) { create(:group, title: 'senseless_group') }
  let(:group) { create(:group, title: 'my_test_group') }
  let(:other_user) { create(:confirmed_user, login: 'other_user') }
  let(:other_user2) { create(:confirmed_user, login: 'other_user2') }
  let(:other_user3) { create(:confirmed_user, login: 'other_user3') }

  context '#save_file' do
    before do
      User.current = user
    end

    it 'calls #addKiwiImport if filename ends with kiwi.txz' do
      expect_any_instance_of(Service).to receive(:addKiwiImport).once
      package.save_file({ filename: 'foo.kiwi.txz' })
    end

    it 'does not call #addKiwiImport if filename ends not with kiwi.txz' do
      expect_any_instance_of(Service).not_to receive(:addKiwiImport)
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
    let(:url) { "#{CONFIG['source_url']}/source/#{home_project.name}/#{package_with_file.name}" }

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

  context '#maintainers' do
    before do
      User.current = user
    end

    it 'returns an array with user objects to all maintainers for a package' do
      # first of all, we add a user who is not a maintainer but a bugowner
      # he/she should not be recognized by package.maintainers
      create(:relationship_package_user_as_bugowner, user: other_user2, package: package)

      # we expect both users to be in that returning array
      create(:relationship_package_user, user: user, package: package)
      create(:relationship_package_user, user: other_user, package: package)

      expect(package.maintainers).to match_array([other_user, user])
    end

    it 'resolves groups properly' do
      # groups should be resolved and only their assigned users should be in the
      # returning array
      group.add_user(other_user)
      group.add_user(other_user2)

      # add a group to the package what is not a maintainer to make sure it'll
      # be ignored when calling package.maintainers
      group_bugowner.add_user(other_user3)

      create(:relationship_package_group_as_bugowner, group: group_bugowner, package: package)
      create(:relationship_package_group, group: group, package: package)

      expect(package.maintainers).to match_array([other_user, other_user2])
    end

    it 'makes sure that no user is listed more than one time' do
      group.add_user(user)
      group_bugowner.add_user(user)

      create(:relationship_package_group, group: group, package: package)
      create(:relationship_package_group, group: group_bugowner, package: package)
      create(:relationship_package_user, user: user, package: package)

      expect(package.maintainers).to match_array([user])
    end

    it 'returns users and the users of resolved groups' do
      group.add_user(user)
      group_bugowner.add_user(other_user)

      create(:relationship_package_group, group: group, package: package)
      create(:relationship_package_group, group: group_bugowner, package: package)
      create(:relationship_package_user, user: other_user2, package: package)

      expect(package.maintainers).to match_array([user, other_user, other_user2])
    end
  end

  context '#file_exists?' do
    context 'with more than one file' do
      it 'returns true if the file exist' do
        expect(package_with_file.file_exists?('somefile.txt')).to eq(true)
      end

      it 'returns false if the file does not exist' do
        expect(package_with_file.file_exists?('not_existent.txt')).to eq(false)
      end
    end

    context 'with one file' do
      let(:package_with_one_file) { create(:package_with_service, name: 'package_with_one_file', project: home_project) }

      it 'returns true if the file exist' do
        expect(package_with_one_file.file_exists?('_service')).to eq(true)
      end

      it 'returns false if the file does not exist' do
        expect(package_with_one_file.file_exists?('not_existent.txt')).to eq(false)
      end
    end
  end

  context '#has_icon?' do
    it 'returns true if the icon exist' do
      if CONFIG['global_write_through']
        Suse::Backend.put("/source/#{CGI.escape(package_with_file.project.name)}/#{CGI.escape(package_with_file.name)}/_icon", Faker::Lorem.paragraph)
      end
      expect(package_with_file.has_icon?).to eq(true)
    end

    it 'returns false if the icon does not exist' do
      expect(package.has_icon?).to eq(false)
    end
  end
end
