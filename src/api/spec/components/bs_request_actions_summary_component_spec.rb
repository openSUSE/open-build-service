RSpec.describe BsRequestActionsSummaryComponent, type: :component do
  let(:bs_request) { instance_double(BsRequest, bs_request_actions: actions) }
  let(:component) { described_class.new(bs_request:) }

  def submits(*names)
    names.map do |name|
      BsRequestActionSubmit.new(source_project: "home:foo:branches:#{name}", source_package: name, target_project: 'openSUSE:Factory')
    end
  end

  def deletes(*names)
    names.map { |name| BsRequestActionDelete.new(target_project: 'openSUSE:Factory', target_package: name) }
  end

  def maintainers(*logins)
    logins.map { |login| BsRequestActionAddRole.new(person_name: login, role: 'maintainer', target_project: 'openSUSE:Factory') }
  end

  def summary(budget)
    component.groups(budget).map { |group| [group.type, group.named_count, group.size] }
  end

  describe '#groups' do
    context 'with 20 submits and 2 role changes' do
      let(:actions) { submits(*Array.new(20) { |i| "pkg#{i}" }) + maintainers('alice', 'bob') }

      it 'names the role changes, then gives what is left to the submits' do
        expect(summary(4)).to eq([['submit', 2, 20], ['add_role', 2, 2]])
      end

      it 'keeps one name for the largest group on narrower screens' do
        expect(summary(2)).to eq([['submit', 1, 20], ['add_role', 2, 2]])
      end

      it 'names nothing on phones' do
        expect(summary(0)).to eq([['submit', 0, 20], ['add_role', 0, 2]])
      end
    end

    context 'with 108 submits and 4 deletes' do
      let(:actions) { submits(*Array.new(108) { |i| "pkg#{i}" }) + deletes('a', 'b', 'c', 'd') }

      it 'still names one of the submits' do
        expect(summary(4)).to eq([['submit', 1, 108], ['delete', 4, 4]])
      end
    end

    context 'with 5 submits' do
      let(:actions) { submits('a', 'b', 'c', 'd', 'e') }

      it 'names the last action instead of showing "+ 1 more"' do
        expect(summary(4)).to eq([['submit', 5, 5]])
      end
    end
  end

  describe 'rendering' do
    context 'with a single submit action' do
      let(:actions) { submits('python-requests') }

      before { render_inline(component) }

      it 'shows the package and the target, without the source project' do
        expect(rendered_content).to have_text('python-requests')
        expect(rendered_content).to have_text('openSUSE:Factory')
        expect(rendered_content).to have_no_text('home:foo:branches')
      end

      it 'shows the source project on hover' do
        expect(rendered_content).to have_css('strong[title="From home:foo:branches:python-requests / python-requests"]')
      end
    end

    context 'with a single submit action to a package with the same name' do
      let(:actions) do
        [BsRequestActionSubmit.new(source_project: 'home:foo:branches:grub2', source_package: 'grub2',
                                   target_project: 'openSUSE:Factory', target_package: 'grub2')]
      end

      before { render_inline(component) }

      it 'shows only the source package' do
        expect(rendered_content).to have_text('openSUSE:Factory')
        expect(rendered_content).to have_no_text('openSUSE:Factory / grub2')
      end
    end

    context 'with a single submit action to a package with a different name' do
      let(:actions) do
        [BsRequestActionSubmit.new(source_project: 'home:foo:branches:grub2', source_package: 'grub2-new',
                                   target_project: 'openSUSE:Factory', target_package: 'grub2')]
      end

      before { render_inline(component) }

      it 'shows the target package' do
        expect(rendered_content).to have_text('openSUSE:Factory / grub2')
      end
    end

    context 'with multiple actions on the same target package' do
      let(:actions) do
        [BsRequestActionDelete.new(target_project: 'openSUSE:Factory', target_package: 'grub2', target_repository: 'standard'),
         BsRequestActionAddRole.new(person_name: 'alice', role: 'maintainer', target_project: 'openSUSE:Factory', target_package: 'grub2')]
      end

      before { render_inline(component) }

      it 'shows the target package' do
        expect(rendered_content).to have_text('openSUSE:Factory / grub2')
      end
    end

    context 'with multiple actions on a target package with the same name as the source package' do
      let(:actions) do
        [BsRequestActionSubmit.new(source_project: 'home:foo', source_package: 'grub2', target_project: 'openSUSE:Factory', target_package: 'grub2'),
         BsRequestActionAddRole.new(person_name: 'alice', role: 'maintainer', target_project: 'openSUSE:Factory', target_package: 'grub2')]
      end

      before { render_inline(component) }

      it 'shows only the source package' do
        expect(rendered_content).to have_text('grub2')
        expect(rendered_content).to have_no_text('openSUSE:Factory / grub2')
      end
    end

    context 'with mixed actions' do
      let(:actions) { submits(*Array.new(20) { |i| "pkg#{i}" }) + maintainers('alice', 'bob') }

      before { render_inline(component) }

      it 'renders the role changes and summarizes the remaining submits for every width' do
        expect(rendered_content).to have_text('alice, bob as maintainer')
        expect(rendered_content).to have_text('+ 18 more')
        expect(rendered_content).to have_text('+ 19 more')
        expect(rendered_content).to have_css('span[title="20 packages"]')
      end

      it 'lists the remaining submits in a popover that stays open while hovered' do
        popover = page.find('span[data-request-actions-popover]', text: '+ 18 more')
        lines = Nokogiri::HTML.fragment(popover['data-bs-content']).css('li').map(&:text)
        expect(lines).to include('pkg19 → openSUSE:Factory')
      end
    end
  end
end
