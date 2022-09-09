require 'rails_helper'

RSpec.describe BsRequestOverviewAvatarsComponent, type: :component do
  describe '#package_avatar_objects' do
    let(:user) { create(:user, login: 'King') }
    let(:review) { create(:review, by_project: package.project.name, by_package: package.name) }
    let(:project) { create(:project_with_package, name: 'Apache', package_name: 'apache2') }
    let(:package) { project.packages.first }
    let(:other_user) { create(:user, login: 'bob', realname: 'Bob') }

    context 'when we have a review by_package' do
      context 'and we have a maintainer assigned to the package' do
        let(:maintainer) { Role.hashed['maintainer'] }

        before do
          package.relationships.create(user: other_user, role: maintainer)
          render_inline(described_class.new(review))
        end

        it 'renders the maintainers of the package' do
          expect(rendered_content).to have_selector('img[title="Bob"]', count: 1)
        end
      end

      context 'but we do not have a maintainer assigned to the package' do
        context 'but we have a maintainer on the packages project' do
          let(:maintainer) { Role.hashed['maintainer'] }

          before do
            project.relationships.create(user: other_user, role: maintainer)
            render_inline(described_class.new(review))
          end

          it 'renders the maintainers of the project' do
            expect(rendered_content).to have_selector('img[title="Bob"]', count: 1)
          end
        end

        context 'and we do not have it anywhere else' do
          before do
            render_inline(described_class.new(review))
          end

          it 'do not render a maintainer' do
            expect(rendered_content).to have_selector('img[title="Bob"]', count: 0)
          end
        end
      end
    end
  end
end
