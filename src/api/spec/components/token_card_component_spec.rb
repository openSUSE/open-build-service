require 'rails_helper'

RSpec.describe TokenCardComponent, type: :component do
  let(:user) { build_stubbed(:confirmed_user) }

  before do
    User.session = user
    render_inline(described_class.new(token: token))
  end

  context 'token with a description' do
    let(:token) { build_stubbed(:rebuild_token, executor: user, description: 'foo_token') }

    it { expect(rendered_content).to have_text('foo_token') }
  end

  context 'token without any optional information' do
    let(:token) { build_stubbed(:rebuild_token, executor: user) }

    it { expect(rendered_content).to have_text('No description') }
    it { expect(rendered_content).to have_text("Id: #{token.id}") }
    it { expect(rendered_content).to have_text("Operation: #{token.class.token_name.capitalize}") }
    it { expect(rendered_content).to have_link(href: "/my/tokens/#{token.id}/edit") }
    it { expect(rendered_content).to have_link(href: "/my/token_triggers/#{token.id}") }
  end

  context 'token with a package assigned' do
    let(:project) { create(:project_with_package) }
    let(:token) { build_stubbed(:rebuild_token, executor: user, package: project.packages.first) }

    it { expect(rendered_content).to have_text('Package:') }
    it { expect(rendered_content).to have_link("#{project.name}/#{project.packages.first.name}") }
  end

  context 'token that got triggered in the past' do
    let(:time_now) { Time.now.utc }
    let(:token) { build_stubbed(:rebuild_token, executor: user, triggered_at: time_now) }

    it { expect(rendered_content).to have_text("Last trigger on #{time_now}") }
  end

  context 'token of type workflow' do
    let(:token) { build_stubbed(:workflow_token, executor: user) }

    it { expect(rendered_content).to have_link(href: "/my/tokens/#{token.id}/workflow_runs") }
  end
end
