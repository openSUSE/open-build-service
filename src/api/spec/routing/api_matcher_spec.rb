require 'rails_helper'

RSpec.describe 'APIMatcher' do
  it { expect(get("/distributions?format=xml")).to route_to(controller: 'distributions', action: 'index', format: 'xml') }

  context '/public and /about path use API routes with html format' do
    it { expect(get("/distributions?format=html")).to_not route_to(controller: 'distributions', action: 'index', format: 'html') }
    it { expect(get("/distributions/about?format=html")).to_not route_to(controller: 'distributions', action: 'show', id: 'about', format: 'html') }
    it { expect(get("/distributions/public?format=html")).to_not route_to(controller: 'distributions', action: 'show', id: 'public', format: 'html') }
  end

  RSpec.shared_examples "/public routes to PublicController independent of format" do |format|
    it { expect(get("/public?format=#{format}")).to route_to(controller: 'public', action: 'index', format: format) }
    it { expect(get("/about?format=#{format}")).to route_to(controller: 'about', action: 'index', format: format) }
    it { expect(get("/public/distributions?format=#{format}")).to route_to(controller: 'public', action: 'distributions', format: format) }
    it { expect(get("/public/request/1?format=#{format}")).to route_to(controller: 'public', action: 'show_request', number: '1', format: format) }
    it { expect(get("/public/configuration?format=#{format}")).to route_to(controller: 'public', action: 'configuration_show', format: format) }

    it {
      expect(get("/public/build/project/repository/arch/package/file.#{format}")).
        to route_to(controller: 'public',
                    action: 'build',
                    project: 'project',
                    repository: 'repository',
                    arch: 'arch',
                    package: 'package',
                    file: 'file',
                    format: format)
    }
    it {
      expect(get("/public/source/project/_meta?format=#{format}")).
        to route_to(controller: 'public', action: 'project_meta', project: 'project', format: format)
    }
    it {
      expect(get("/public/source/project?format=#{format}")).
        to route_to(controller: 'public', action: 'project_index', project: 'project', format: format)
    }
    it {
      expect(get("/public/source/project/_config?format=#{format}")).
        to route_to(controller: 'public', action: 'project_file', project: 'project', format: format)
    }
    it {
      expect(get("/public/source/project/package?format=#{format}")).
        to route_to(controller: 'public', action: 'package_index', project: 'project', package: 'package', format: format)
    }
    it {
      expect(get("/public/source/project/package/_meta?format=#{format}")).
        to route_to(controller: 'public', action: 'package_meta', project: 'project', package: 'package', format: format)
    }
    it {
      expect(get("/public/source/project/package/file?format=#{format}")).
        to route_to(controller: 'public', action: 'source_file', project: 'project', package: 'package', filename: 'file', format: format)
    }
    it {
      expect(get("/public/binary_packages/project/package?format=#{format}")).
        to route_to(controller: 'public', action: 'binary_packages', project: 'project', package: 'package', format: format)
    }
  end

  include_examples "/public routes to PublicController independent of format", "html"
  include_examples "/public routes to PublicController independent of format", "xml"

  it 'routes requests to global_command_* correctly' do
    expect(post('/source?cmd=orderkiwirepos')).to route_to(
      controller: 'source',
      action:     'global_command_orderkiwirepos',
      cmd:        'orderkiwirepos'
    )

    expect(post('/source?cmd=branch')).to route_to(
      controller: 'source',
      action:     'global_command_branch',
      cmd:        'branch'
    )

    expect(post('/source?cmd=createmaintenanceincident')).to route_to(
      controller: 'source',
      action:     'global_command_createmaintenanceincident',
      cmd:        'createmaintenanceincident'
    )
  end
end
