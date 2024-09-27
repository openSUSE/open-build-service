RSpec.describe BuildresultStatusLinkComponent, type: :component do
  let(:project_name) { 'home:foo' }
  let(:package_name) { 'hello_world' }
  let(:architecture_name) { 'x86_64' }
  let(:repository_name) { 'openSUSE_Tumbleweed' }
  let(:build_details) { '' }

  before do
    render_inline(described_class.new(repository_name: repository_name, architecture_name: architecture_name,
                                      project_name: project_name, package_name: package_name,
                                      build_status: build_status, build_details: build_details))
  end

  context 'for a scheduled build job with constraints' do
    let(:build_status) { 'scheduled' }
    let(:build_details) { 'Some details about the build' }

    it 'renders a span tag with text-warning style and build status scheduled' do
      expect(rendered_content).to have_css('span.text-warning.toggle-build-info',
                                           id: "id-#{package_name}_#{repository_name}_#{architecture_name}",
                                           text: 'scheduled')
    end
  end

  context 'for build states without a live log' do
    let(:build_status) { 'blocked' }

    it 'renders a span tag with the correct id and class' do
      expect(rendered_content).to have_css("span.build-state-#{build_status}.toggle-build-info",
                                           id: "id-#{package_name}_#{repository_name}_#{architecture_name}",
                                           text: build_status.to_s)
    end
  end

  context 'for build states providing a live log' do
    let(:build_status) { 'succeeded' }

    it 'renders a link with the correct class' do
      expect(rendered_content).to have_text(build_status.to_s)
      expect(rendered_content).to have_link(href: "/package/live_build_log/#{project_name}/#{package_name}/#{repository_name}/#{architecture_name}",
                                            class: "build-state-#{build_status}")
    end
  end
end
