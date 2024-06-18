RSpec.describe UserAvatarComponent, type: :component do
  describe '#avatar_object' do
    let(:user) { create(:user, login: 'King') }
    let(:project) { create(:project_with_package, name: 'Apache', package_name: 'apache2') }
    let(:package) { project.packages.first }
    let(:other_user) { create(:user, login: 'bob', realname: 'Bob') }

    context 'when we have a review by_package' do
      context 'and we have a maintainer assigned to the package' do
        let(:maintainer) { Role.hashed['maintainer'] }

        before do
          package.relationships.create(user: other_user, role: maintainer)
          render_inline(described_class.new(other_user))
        end

        it 'renders the maintainers of the package' do
          expect(rendered_content).to have_css('img[title="Bob"]', count: 1)
        end
      end
    end
  end
end
