require 'rails_helper'
# WARNING: If you change owner tests make sure you uncomment this line
# and start a test backend. Some of the Owner methods
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.describe Webui::PackageController, vcr: true do
  let(:admin) { create(:admin_user, login: "admin") }
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:source_project) { user.home_project }
  let(:source_package) { create(:package, name: 'my_package', project: source_project) }
  let(:target_project) { create(:project) }
  let(:package) { create(:package_with_file, name: "package_with_file", project: source_project) }
  let(:repo_for_source_project) do
    repo = create(:repository, project: source_project, architectures: ['i586'])
    source_project.store
    repo
  end
  let(:fake_build_results) do
      Buildresult.new(
        '<resultlist state="2b71f05ecb8742e3cd7f6066a5097c72">
          <result project="home:tom" repository="fake_repo_name" arch="i586" code="unknown" state="unknown" dirty="true">
           <binarylist>
              <binary filename="fake_binary_001"/>
              <binary filename="fake_binary_002"/>
              <binary filename="updateinfo.xml"/>
              <binary filename="rpmlint.log"/>
            </binarylist>
          </result>
        </resultlist>')
  end
  let(:fake_build_results_without_binaries) do
      Buildresult.new(
        '<resultlist state="2b71f05ecb8742e3cd7f6066a5097c72">
          <result project="home:tom" repository="fake_repo_name" arch="i586" code="unknown" state="unknown" dirty="true">
           <binarylist>
            </binarylist>
          </result>
        </resultlist>')
  end

  describe "POST #submit_request" do
    RSpec.shared_examples "a response of a successful submit request" do
      it { expect(flash[:notice]).to match("Created .+submit request \\d.+to .+#{target_project}") }
      it { expect(response).to redirect_to(package_show_path(project: source_project, package: package)) }
      it { expect(BsRequestActionSubmit.where(target_project: target_project.name, target_package: package.name)).to exist }
    end

    before do
      login(user)
    end

    context "sending a valid submit request" do
      before do
        post :submit_request, { project: source_project, package: package, targetproject: target_project }
      end

      it_should_behave_like "a response of a successful submit request"
    end

    context "having whitespaces in parameters" do
      before do
        post :submit_request, { project: " #{source_project} ", package: " #{package} ", targetproject: " #{target_project} " }
      end

      it_should_behave_like "a response of a successful submit request"
    end

    context 'not successful' do
      before do
        post :submit_request, { project: source_project, package: source_package, targetproject: target_project.name }
      end

      it { expect(flash[:error]).to eq('Unable to submit: The source of package home:tom/my_package is broken') }
      it { expect(response).to redirect_to(package_show_path(project: source_project, package: source_package)) }
      it { expect(BsRequestActionSubmit.where(target_project: target_project.name, target_package: source_package.name)).not_to exist }
    end

    context "a submit request that fails due to validation errors" do
      let(:unconfirmed_user) { create(:user) }

      before do
        login(unconfirmed_user)
        post :submit_request, { project: source_project, package: package, targetproject: target_project }
      end

      it { expect(flash[:error]).to eq("Unable to submit: Validation failed: Creator Login #{unconfirmed_user.login} is not an active user") }
      it { expect(response).to redirect_to(package_show_path(project: source_project, package: package)) }
      it { expect(BsRequestActionSubmit.where(target_project: target_project.name, target_package: package.name)).not_to exist }
    end

    context "unchanged sources" do
      before do
        post :submit_request, { project: source_project, package: package, targetproject: source_project }
      end

      it { expect(flash[:error]).to eq("Unable to submit, sources are unchanged") }
      it { expect(response).to redirect_to(package_show_path(project: source_project, package: package)) }
      it { expect(BsRequestActionSubmit.where(target_project: source_project.name, target_package: package.name)).not_to exist }
    end

    context "invalid request (missing parameters)" do
      before do
        post :submit_request, { project: source_project, package: "", targetproject: source_project }
      end

      it { expect(flash[:error]).to eq("Unable to submit: #{source_project}/") }
      it { expect(response).to redirect_to(project_show_path(project: source_project)) }
      it { expect(BsRequestActionSubmit.where(target_project: source_project.name)).not_to exist }
    end
  end

  describe 'POST #save' do
    before do
      login(user)
      post :save, { project: source_project, package: source_package, title: 'New title for package', description: 'New description for package' }
    end

    it { expect(flash[:notice]).to eq("Package data for '#{source_package.name}' was saved successfully") }
    it { expect(source_package.reload.title).to eq('New title for package') }
    it { expect(source_package.reload.description).to eq('New description for package') }
    it { expect(response).to redirect_to(package_show_path(project: source_project, package: source_package)) }
  end

  describe "POST #save_new_link" do
    before do
      login(user)
    end

    it "shows an error if source package doesn't exist" do
      post :save_new_link, project: user.home_project, linked_project: source_project
      expect(flash[:error]).to eq("Failed to branch: Package does not exist.")
      expect(response).to redirect_to(root_path)
    end

    it "shows an error if source project doesn't exist" do
      post :save_new_link, project: user.home_project
      expect(flash[:error]).to eq("Failed to branch: Package does not exist.")
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST #remove" do
    before do
      login(user)
    end

    describe "authentification" do
      let(:target_package) { create(:package, name: "forbidden_package", project: target_project) }

      it "does not allow other users than the owner to delete a package" do
        post :remove, project: target_project, package: target_package

        expect(flash[:error]).to eq("Sorry, you are not authorized to delete this Package.")
        expect(target_project.packages).not_to be_empty
      end

      it "allows admins to delete other user's packages" do
        login(admin)
        post :remove, project: target_project, package: target_package

        expect(flash[:notice]).to eq("Package was successfully removed.")
        expect(target_project.packages).to be_empty
      end
    end

    context "a package" do
      before do
        post :remove, project: user.home_project, package: source_package
      end

      it { expect(response).to have_http_status(:found) }
      it { expect(flash[:notice]).to eq("Package was successfully removed.") }
      it "deletes the package" do
        expect(user.home_project.packages).to be_empty
      end
    end

    context "a package with dependencies" do
      let(:devel_project) { create(:package, project: target_project) }

      before do
        source_package.develpackages << devel_project
      end

      it "does not delete the package and shows an error message" do
        post :remove, project: user.home_project, package: source_package

        expect(flash[:notice]).to eq "Package can't be removed: used as devel package by #{target_project}/#{devel_project}"
        expect(user.home_project.packages).not_to be_empty
      end

      context "forcing the deletion" do
        before do
          post :remove, project: user.home_project, package: source_package, force: true
        end

        it "deletes the package" do
          expect(flash[:notice]).to eq "Package was successfully removed."
          expect(user.home_project.packages).to be_empty
        end
      end
    end
  end

  describe 'GET #binaries' do
    before do
      login user
    end

    after do
      Package.destroy_all
      Repository.destroy_all
    end

    context 'with a failure in the backend' do
      before do
        Buildresult.stubs(:find_hashed).raises(ActiveXML::Transport::Error, 'fake message')
        post :binaries, package: source_package, project: source_project, repository: repo_for_source_project
      end

      it { expect(flash[:error]).to eq('fake message') }
      it { expect(response).to redirect_to(package_show_path(project: source_project, package: source_package)) }
    end

    context 'without build results' do
      before do
        Buildresult.stubs(:find_hashed).returns(nil)
        post :binaries, package: source_package, project: source_project, repository: repo_for_source_project
      end

      it { expect(flash[:error]).to eq("Package \"#{source_package}\" has no build result for repository #{repo_for_source_project.to_param}") }
      it { expect(response).to redirect_to(package_show_path(project: source_project, package: source_package, nextstatus: 404)) }
    end

    context 'with build results and no binaries' do
      render_views

      before do
        Buildresult.stubs(:find).returns(fake_build_results_without_binaries)
        post :binaries, package: source_package, project: source_project, repository: repo_for_source_project
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(response.body).to match(/No built binaries/) }
    end

    context 'with build results and binaries' do
      render_views

      before do
        Buildresult.stubs(:find).returns(fake_build_results)
        post :binaries, package: source_package, project: source_project, repository: repo_for_source_project
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(response.body).to match(/fake_binary_001/) }
      it { expect(response.body).to match(/fake_binary_002/) }
      it { expect(response.body).to match(/updateinfo.xml/) }
      it { expect(response.body).to match(/rpmlint.log/) }
    end
  end

  describe "POST #save_file" do
    before do
      login(user)
    end

    context "without any uploaded file data" do
      it "fails with an error message" do
        post :save_file, project: source_project, package: source_package
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("Error while creating '' file: No file or URI given.")
      end
    end

    context "with an invalid filename" do
      it "fails with a backend error message" do
        post :save_file, project: source_project, package: source_package, filename: ".test"
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("Error while creating '.test' file: filename '.test' is illegal.")
      end
    end

    context "adding a file that doesn't exist yet" do
      before do
        post :save_file, project: source_project, package: source_package, filename: "newly_created_file",
          file_type: "local"
      end

      it { expect(response).to have_http_status(:found) }
      it { expect(flash[:success]).to eq("The file 'newly_created_file' has been successfully saved.") }
      it { expect(source_package.source_file("newly_created_file")).to be nil }
    end

    context "uploading a utf-8 file" do
      let(:file_to_upload) { File.read(File.expand_path(Rails.root.join("spec/support/files/chinese.txt"))) }

      before do
        post :save_file, project: source_project, package: source_package, filename: "学习总结",
          file: file_to_upload
      end

      it { expect(response).to have_http_status(:found) }
      it { expect(flash[:success]).to eq("The file '学习总结' has been successfully saved.") }
      it "creates the file" do
        expect { source_package.source_file("学习总结") }.not_to raise_error
        expect(URI.encode(source_package.source_file("学习总结"))).to eq(URI.encode(file_to_upload))
      end
    end

    context "uploading a file from remote URL" do
      before do
        post :save_file, project: source_project, package: source_package, filename: "remote_file",
          file_url: "https://raw.github.com/openSUSE/open-build-service/master/.gitignore"
      end

      it { expect(response).to have_http_status(:found) }
      it { expect(flash[:success]).to eq("The file 'remote_file' has been successfully saved.") }
      # Uploading a remote file creates a service instead of downloading it directly!
      it "creates a valid service file" do
        expect { source_package.source_file("_service") }.not_to raise_error
        expect { source_package.source_file("remote_file") }.to raise_error ActiveXML::Transport::NotFoundError

        created_service = source_package.source_file("_service")
        expect(created_service).to eq(<<-EOT.strip)
<services>
  <service name="download_url">
    <param name="host">raw.github.com</param>
    <param name="protocol">https</param>
    <param name="path">/openSUSE/open-build-service/master/.gitignore</param>
    <param name="filename">remote_file</param>
  </service>
</services>
EOT
      end
    end

    context "uploading a valid special file (_aggregate)" do
      let(:file_to_upload) { File.read(File.expand_path(Rails.root.join("test/texts/aggregate.xml"))) }

      before do
        post :save_file, project: source_project, package: source_package, file: file_to_upload, filename: "_aggregate"
      end

      it { expect(response).to have_http_status(:found) }
      it { expect(flash[:success]).to eq("The file '_aggregate' has been successfully saved.") }

      it "create the '_aggregate' file" do
        expect { source_package.source_file("_aggregate") }.not_to raise_error
        expect(URI.encode(source_package.source_file("_aggregate"))).to eq(URI.encode(file_to_upload))
      end
    end

    context "uploading an invalid special file (_link)" do
      before do
        post :save_file, project: source_project, package: source_package, filename: "_link",
          file: File.expand_path(Rails.root.join("test/texts/broken_link.xml"))
      end

      it { expect(response).to have_http_status(:found) }
      it { expect(flash[:error]).to eq("Error while creating '_link' file: link validation error: Start tag expected, '<' not found.") }
      it "does not create a '_link' file" do
        expect { source_package.source_file("_link") }.to raise_error ActiveXML::Transport::NotFoundError
      end
    end
  end
end
