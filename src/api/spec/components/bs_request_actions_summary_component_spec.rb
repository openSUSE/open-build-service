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

  def variant(breakpoint)
    component.variants.find { |variant| variant.breakpoint == breakpoint }
  end

  def summary(breakpoint)
    variant(breakpoint).groups.map { |group| [group.type, group.named_count, group.size] }
  end

  describe '#variants' do
    context 'with 20 submits and 2 role changes' do
      let(:actions) { submits(*Array.new(20) { |i| "pkg#{i}" }) + maintainers('alice', 'bob') }

      it 'names the role changes, then gives what is left to the submits' do
        expect(summary(:wide)).to eq([['submit', 2, 20], ['add_role', 2, 2]])
      end

      it 'keeps one name for the largest group on narrower screens' do
        expect(summary(:medium)).to eq([['submit', 1, 20], ['add_role', 2, 2]])
      end

      it 'names nothing on phones' do
        expect(summary(:narrow)).to eq([['submit', 0, 20], ['add_role', 0, 2]])
      end

      it 'has no verb, the actions have different types' do
        expect(component.variants.map(&:verb)).to all(be_nil)
      end

      it 'gives the role changes their shared role' do
        expect(variant(:wide).groups.map(&:role)).to eq([nil, 'maintainer'])
      end
    end

    context 'with role changes for different roles' do
      let(:actions) do
        submits('a') + maintainers('alice') + [BsRequestActionAddRole.new(person_name: 'bob', role: 'bugowner', target_project: 'openSUSE:Factory')]
      end

      it 'has no shared role' do
        expect(variant(:wide).groups.find { |group| group.type == 'add_role' }.role).to be_nil
      end
    end

    context 'with 108 submits and 4 deletes' do
      let(:actions) { submits(*Array.new(108) { |i| "pkg#{i}" }) + deletes('a', 'b', 'c', 'd') }

      it 'still names one of the submits' do
        expect(summary(:wide)).to eq([['submit', 1, 108], ['delete', 4, 4]])
      end
    end

    context 'with 5 submits' do
      let(:actions) { submits('a', 'b', 'c', 'd', 'e') }

      it 'names the last action instead of showing "+ 1 more"' do
        expect(summary(:wide)).to eq([['submit', 5, 5]])
      end

      it 'has the verb of the action type when names are shown' do
        verbs = component.variants.map { |variant| [variant.breakpoint, variant.verb] }
        expect(verbs).to eq([[:wide, 'Submit'], [:medium, 'Submit'], [:narrow, nil]])
      end
    end
  end

  describe '#target_label' do
    context 'with actions on several projects' do
      let(:actions) { submits('a') + [BsRequestActionSubmit.new(source_project: 'home:foo', source_package: 'b', target_project: 'openSUSE:Leap')] }

      it { expect(component.target_label).to be_nil }
    end

    context 'with actions on one project' do
      let(:actions) { submits('a', 'b') }

      it { expect(component.target_label).to eq('openSUSE:Factory') }
    end

    context 'with actions on one package with a different name than the source package' do
      let(:actions) do
        [BsRequestActionDelete.new(target_project: 'openSUSE:Factory', target_package: 'grub2', target_repository: 'standard'),
         BsRequestActionAddRole.new(person_name: 'alice', role: 'maintainer', target_project: 'openSUSE:Factory', target_package: 'grub2')]
      end

      it { expect(component.target_label).to eq('openSUSE:Factory / grub2') }
    end
  end

  describe 'rendering' do
    context 'with a single submit action' do
      let(:actions) { submits('python-requests') }

      before { render_inline(component) }

      it 'shows the package and the target' do
        expect(rendered_content).to have_text('Submit python-requests', normalize_ws: true)
        expect(rendered_content).to have_text('openSUSE:Factory')
      end

      it 'does not show the source project' do
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

    context 'with only submit actions' do
      let(:actions) { submits('grub2', 'shim', 'elilo') }

      before { render_inline(component) }

      it 'starts with the verb' do
        expect(rendered_content).to have_text('Submit grub2, shim, elilo', normalize_ws: true)
      end
    end

    context 'with a change devel action' do
      let(:actions) do
        [BsRequestActionChangeDevel.new(source_project: 'devel:tools', source_package: 'grub2',
                                        target_project: 'openSUSE:Factory', target_package: 'grub2')]
      end

      before { render_inline(component) }

      it 'shows the package, its project and the new devel project' do
        expect(rendered_content).to have_text('Change devel of grub2 in openSUSE:Factory to devel:tools', normalize_ws: true)
      end
    end

    context 'with a change devel action without a target package' do
      let(:actions) { [BsRequestActionChangeDevel.new(source_project: 'devel:tools', target_project: 'openSUSE:Factory')] }

      before { render_inline(component) }

      it 'shows the project only once' do
        expect(rendered_content).to have_text('Change devel of openSUSE:Factory to devel:tools', normalize_ws: true)
      end
    end

    context 'with mixed actions' do
      let(:actions) { submits(*Array.new(20) { |i| "pkg#{i}" }) + maintainers('alice', 'bob') }

      before { render_inline(component) }

      it 'renders the role changes' do
        expect(rendered_content).to have_text('alice, bob as maintainer', normalize_ws: true)
      end

      it 'summarizes the remaining submits for every width' do
        expect(rendered_content).to have_text('+ 18 more')
        expect(rendered_content).to have_text('+ 19 more')
      end

      it 'shows total package count on narrow screens' do
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
