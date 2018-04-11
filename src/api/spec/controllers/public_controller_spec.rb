# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'
# WARNING: If you change tests make sure you uncomment this line
# and start a test backend. Some of the actions
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.describe PublicController, vcr: true do
  let(:project) { create(:project, name: 'public_controller_project', title: 'The Public Controller Project') }
  let(:package) { create(:package_with_file, name: 'public_controller_package', project: project) }

  describe 'GET #source_file' do
    before do
      get :source_file, params: { project: project.name, package: package.name, filename: 'somefile.txt' }
    end

    it { is_expected.to respond_with(:success) }
    it { expect(response.body).to eq(package.source_file('somefile.txt')) }
  end

  describe 'GET #index' do
    before do
      get :index
    end

    it { is_expected.to redirect_to(about_index_path) }
  end

  describe 'GET #build' do
    before do
      get :build, params: { project: project.name }
    end

    it { is_expected.to respond_with(:success) }
    it { expect(a_request(:get, /.*\/build\/public_controller_project/)).to have_been_made.once }
  end

  describe 'GET #configuration' do
    context 'as JSON format' do
      before do
        get :configuration_show, params: { format: :json }
      end

      it { is_expected.to respond_with(:success) }
      it { expect(assigns(:configuration)).to eq(Configuration.first) }
    end

    context 'as XML format' do
      before do
        get :configuration_show
      end

      it { is_expected.to respond_with(:success) }
      it { expect(assigns(:configuration)).to eq(Configuration.first) }
    end
  end

  describe 'GET #project_meta' do
    before do
      get :project_meta, params: { project: project.name }
    end

    it { is_expected.to respond_with(:success) }
    it { expect(response.body).to match(/<project name="public_controller_project">/) }
    it { expect(a_request(:get, /.*\/source\/public_controller_project\/_meta/)).to have_been_made.once }
  end

  describe 'GET #project_index' do
    context 'without view specified' do
      before do
        get :project_index, params: { project: project.name }
      end

      it { expect(assigns(:project)).to eq(project) }
      it { is_expected.to respond_with(:success) }
      it { expect(response.body).to match(/<entry name="public_controller_package"/) }
      it { expect(a_request(:get, /.*\/source\/public_controller_project\?expand=1&noorigins=1/)).to have_been_made.once }
    end

    context "with 'info' view specified" do
      context "and nofilename is not equal '1'" do
        before do
          get :project_index, params: { project: project.name, view: 'info', nofilename: 'filename' }
        end

        it { is_expected.to respond_with(400) }
        it { expect(a_request(:get, /.*\/source\/public_controller_project\?nofilename=1&view=info/)).not_to have_been_made }
      end

      context "and nofilename is equal '1'" do
        before do
          get :project_index, params: { project: project.name, view: 'info', nofilename: '1' }
        end

        it { expect(assigns(:project)).to eq(project) }
        it { is_expected.to respond_with(:success) }
        it { expect(a_request(:get, /.*\/source\/public_controller_project\?nofilename=1&view=info/)).to have_been_made.once }
      end
    end

    context "with 'verboseproductlist' view specified" do
      before do
        get :project_index, params: { project: project.name, view: 'verboseproductlist' }
      end

      it { expect(assigns(:project)).to eq(project) }
      it { is_expected.to respond_with(:success) }
      it { expect(assigns(:products)).to eq(Product.all_products(project, 0)) }
      it { expect(subject).to render_template('source/verboseproductlist') }
    end

    context "with 'productlist' view specified" do
      before do
        get :project_index, params: { project: project.name, view: 'productlist' }
      end

      it { expect(assigns(:project)).to eq(project) }
      it { is_expected.to respond_with(:success) }
      it { expect(assigns(:products)).to eq(Product.all_products(project, 0)) }
      it { expect(subject).to render_template('source/productlist') }
    end
  end

  describe 'GET #project_file' do
    before do
      get :project_file, params: { project: project.name }
    end

    it { is_expected.to respond_with(:success) }
    it { expect(a_request(:get, /.*\/source\/public_controller_project\/_config/)).to have_been_made }
    it { expect(response.body).to eq(project.source_file('_config')) }
  end

  describe 'GET #package_index' do
    before do
      get :package_index, params: { project: project.name, package: package.name }
    end

    it { is_expected.to respond_with(:success) }
    it { expect(response.body).to match(/name="somefile.txt"/) }
    it { expect(a_request(:get, /.*\/source\/public_controller_project\/public_controller_package/)).to have_been_made.once }
  end

  describe 'GET #package_meta' do
    before do
      get :package_meta, params: { project: project.name, package: package.name }
    end

    it { is_expected.to respond_with(:success) }
    it { expect(response.body).to match(/<package name="public_controller_package" project="public_controller_project">/) }
    it { expect(a_request(:get, /.*\/source\/public_controller_project\/public_controller_package\/_meta/)).to have_been_made.once }
  end

  describe 'GET #distributions' do
    before do
      get :distributions, params: { format: :xml }
    end

    it { is_expected.to respond_with(:success) }
    it { expect(assigns(:distributions)).to eq(Distribution.all_as_hash) }
  end

  describe 'GET #show_request' do
    let(:request) { create(:bs_request) }

    before do
      get :show_request, params: { number: request.number }
    end

    it { is_expected.to respond_with(:success) }
    it { expect(response.body).to eq(request.render_xml) }
  end

  describe 'GET #binary_packages' do
    before do
      get :binary_packages, params: { project: project.name, package: package.name }
    end

    it { is_expected.to respond_with(:success) }
    it { expect(assigns(:pkg)).to eq(package) }
  end

  describe 'GET #source_file history' do
    context 'with history unlimited' do
      before do
        get :source_file, params: { project: project.name, package: package.name, filename: '_history' }
        @revisions = Nokogiri::XML(response.body).xpath('//revision')
      end
      it { is_expected.to respond_with(:success) }
      it { expect(@revisions.count).to be > 1 }
    end

    context 'with history limited to 1' do
      before do
        get :source_file, params: { project: project.name, package: package.name, filename: '_history', limit: 1 }
        @revisions = Nokogiri::XML(response.body).xpath('//revision')
      end
      it { is_expected.to respond_with(:success) }
      it { expect(@revisions.count).to eq 1 }
    end
  end
end
