RSpec.describe Package, '#get_by_project_and_name' do
  # follow_multibuild is tested in spec/models/concerns/multibuild_package_spec.rb
  # use_source is tested in spec/models/user_has_local_permission_spec.rb

  subject { Package.get_by_project_and_name(project.name, package.name, arguments) }

  context 'follow_project_links' do
    # With `follow_project_links: true` it will "follow" project links and find the Package from the Project the link points to.
    # https://github.com/openSUSE/open-build-service/wiki/Links#project-links
    context 'enabled' do
      let(:arguments) { { follow_project_links: true } }

      context 'and local project link' do
        let(:local_linked_project) { create(:project, name: 'project_2') }
        let(:project) { create(:project, name: 'project_1') }
        let(:link_association) { create(:linked_project, project: project, linked_db_project: local_linked_project) }

        context 'and linked project provides package and local project not' do
          let(:package) { create(:package, project: link_association.linked_db_project) }

          it 'returns the package from the link' do
            expect(subject.project).equal?(local_linked_project)
          end
        end

        context 'and linked project provides package and local project also provides package' do
          let(:package_in_link) { create(:package, name: 'package_1', project: link_association.linked_db_project) }
          let(:package) { create(:package, name: package_in_link.name, project: link_association.project) }

          it 'returns the package from the local project' do
            expect(subject.project).equal?(project)
          end
        end

        context 'and linked project does not provide package and local project also not' do
          let(:package) { build(:package, name: 'i_do_not_exist') }

          it 'raises' do
            expect { subject }.to raise_error(Package::Errors::UnknownObjectError)
          end
        end
      end

      context 'and remote project link' do
        let(:project) do
          project = create(:project, name: 'project_1')
          create(:linked_project, project: project, linked_remote_project_name: 'openSUSE.org:home:hennevogel:myfirstproject')
          project
        end
        let(:package) { build(:package, name: 'i_might_exist_remote') }

        it 'returns nil' do
          expect(subject).equal?(nil)
        end

        it 'does not raise' do
          expect { subject }.not_to raise_error
        end
      end
    end

    context 'disabled' do
      let(:arguments) { { follow_project_links: false } }

      context 'and local project link' do
        let(:local_linked_project) { create(:project, name: 'project_2') }
        let(:project) { create(:project, name: 'project_1') }
        let(:link_association) { create(:linked_project, project: project, linked_db_project: local_linked_project) }

        context 'and linked project provides package and local project not' do
          let(:package) { create(:package, project: link_association.linked_db_project) }

          it 'raises' do
            expect { subject }.to raise_error(Package::Errors::UnknownObjectError)
          end
        end

        context 'and linked project provides package and local project also provides package' do
          let(:package_in_link) { create(:package, name: 'package_1', project: link_association.linked_db_project) }
          let(:package) { create(:package, name: package_in_link.name, project: link_association.project) }

          it 'returns the package from the local project' do
            expect(subject.project).equal?(project)
          end
        end

        context 'and linked project does not provide package and local project also not' do
          let(:package) { build(:package, name: 'i_do_not_exist') }

          it 'raises' do
            expect { subject }.to raise_error(Package::Errors::UnknownObjectError)
          end
        end
      end

      context 'and remote project link' do
        let(:project) do
          project = create(:project, name: 'project_1')
          create(:linked_project, project: project, linked_remote_project_name: 'openSUSE.org:home:hennevogel:myfirstproject')
          project
        end
        let(:package) { build(:package, name: 'i_might_exist_remote') }

        it 'raises' do
          expect { subject }.to raise_error(Package::Errors::UnknownObjectError)
        end
      end
    end
  end

  context 'check_update_project' do
    # With `check_update_project: true` it will "follow" this type of project link to find the Package from the "update project".
    # https://github.com/openSUSE/open-build-service/wiki/Links#update-instance-project-links
    context 'enabled' do
      let(:arguments) { { check_update_project: true } }
      let(:update_project) { create(:project) }
      let(:project) do
        project = create(:project)
        create(:update_project_attrib, project: project, update_project: update_project)
        project
      end

      context 'and linked project provides package and local project not' do
        let(:package) { create(:package, project: update_project) }

        it 'returns the package from the link' do
          expect(subject.project).equal?(update_project)
        end
      end

      context 'and linked project provides package and local project also provides package' do
        let(:updated_package) { create(:package, project: update_project) }
        let(:package) { create(:package, name: updated_package.name, project: project) }

        it 'returns the package from the link' do
          expect(subject.project).equal?(update_project)
        end
      end

      context 'and linked project does not provide package and local project also not' do
        let(:package) { build(:package, name: 'i_do_not_exist') }

        it 'raises' do
          expect { subject }.to raise_error(Package::Errors::UnknownObjectError)
        end
      end
    end

    context 'disabled' do
      let(:arguments) { { check_update_project: false } }
      let(:update_project) { create(:project) }
      let(:project) do
        project = create(:project)
        create(:update_project_attrib, project: project, update_project: update_project)
        project
      end

      context 'and linked project provides package and local project not' do
        let(:package) { create(:package, project: update_project) }

        it 'raises' do
          expect { subject }.to raise_error(Package::Errors::UnknownObjectError)
        end
      end

      context 'and linked project provides package and local project also provides package' do
        let(:updated_package) { create(:package, project: update_project) }
        let(:package) { create(:package, name: updated_package.name, project: project) }

        it 'does not find the package from the link' do
          expect(subject.project).equal?(project)
        end
      end

      context 'and linked project does not provide package and local project also not' do
        let(:package) { build(:package, name: 'i_dont_exist') }

        it 'raises' do
          expect { subject }.to raise_error(Package::Errors::UnknownObjectError)
        end
      end
    end
  end
end
