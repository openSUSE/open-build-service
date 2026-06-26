RSpec.describe 'RoutesHelper::APIMatcher' do
  it { expect(get('/distributions?format=xml')).to route_to(controller: 'distributions', action: 'index', format: 'xml') }

  RSpec.shared_examples '/public routes to PublicController independent of format' do |format|
    it { expect(get("/public/distributions?format=#{format}")).to route_to(controller: 'public', action: 'distributions', format: format) }
    it { expect(get("/public/request/1?format=#{format}")).to route_to(controller: 'public', action: 'show_request', number: '1', format: format) }
    it { expect(get("/public/configuration?format=#{format}")).to route_to(controller: 'public', action: 'configuration_show', format: format) }

    it {
      expect(get("/public/build/project/repository/arch/package/filename?format=#{format}"))
        .to route_to(controller: 'public',
                     action: 'build',
                     project: 'project',
                     repository: 'repository',
                     arch: 'arch',
                     package: 'package',
                     filename: 'filename',
                     format: format)
    }

    it {
      expect(get("/public/source/project/_meta?format=#{format}"))
        .to route_to(controller: 'public', action: 'project_meta', project: 'project', format: format)
    }

    it {
      expect(get("/public/source/project?format=#{format}"))
        .to route_to(controller: 'public', action: 'project_index', project: 'project', format: format)
    }

    it {
      expect(get("/public/source/project/_config?format=#{format}"))
        .to route_to(controller: 'public', action: 'project_file', project: 'project', format: format)
    }

    it {
      expect(get("/public/source/project/package?format=#{format}"))
        .to route_to(controller: 'public', action: 'package_index', project: 'project', package: 'package', format: format)
    }

    it {
      expect(get("/public/source/project/package/_meta?format=#{format}"))
        .to route_to(controller: 'public', action: 'package_meta', project: 'project', package: 'package', format: format)
    }

    it {
      expect(get("/public/source/project/package/file?format=#{format}"))
        .to route_to(controller: 'public', action: 'source_file', project: 'project', package: 'package', filename: 'file', format: format)
    }

    it {
      expect(get("/public/binary_packages/project/package?format=#{format}"))
        .to route_to(controller: 'public', action: 'binary_packages', project: 'project', package: 'package', format: format)
    }
  end

  it_behaves_like '/public routes to PublicController independent of format', 'html'
  it_behaves_like '/public routes to PublicController independent of format', 'xml'

  it 'routes requests to global_command_* correctly' do
    expect(post('/source?cmd=orderkiwirepos')).to route_to(
      controller: 'source_command',
      action: 'global_command_orderkiwirepos',
      cmd: 'orderkiwirepos'
    )

    expect(post('/source?cmd=branch')).to route_to(
      controller: 'source_command',
      action: 'global_command_branch',
      cmd: 'branch'
    )

    expect(post('/source?cmd=createmaintenanceincident')).to route_to(
      controller: 'source_command',
      action: 'global_command_createmaintenanceincident',
      cmd: 'createmaintenanceincident'
    )
  end
end
