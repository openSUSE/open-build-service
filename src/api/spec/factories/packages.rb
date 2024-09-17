FactoryBot.define do
  factory :package do
    project
    sequence(:name) { |n| "package_#{n}" }
    title { Faker::Book.title }
    description { Faker::Lorem.sentence }

    after(:build) do |package|
      package.commit_user ||= build(:confirmed_user)
    end

    trait :as_submission_source do
      after(:create) do |package, _evaluator|
        create(:approved_request_source_attrib, project: package.project)
      end
    end

    factory :package_with_maintainer do
      transient do
        maintainer { association :confirmed_user }
      end

      after(:build) do |package, evaluator|
        role = Role.find_by_title('maintainer')
        if evaluator.maintainer.is_a?(User)
          package.relationships.build(user: evaluator.maintainer, role: role)
        elsif evaluator.maintainer.is_a?(Group)
          package.relationships.build(group: evaluator.maintainer, role: role)
        end
      end
    end

    factory :package_with_revisions do
      transient do
        revision_count { 2 }
      end

      after(:create) do |package, evaluator|
        evaluator.revision_count.times do |i|
          Backend::Connection.put("/source/#{package.project}/#{package}/somefile.txt", i.to_s) if CONFIG['global_write_through']
        end
      end
    end

    factory :package_with_file do
      transient do
        file_name { 'somefile.txt' }
        file_content { Faker::Lorem.paragraph }
      end

      after(:create) do |package, evaluator|
        if CONFIG['global_write_through']
          Backend::Connection.put("/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/_config", Faker::Lorem.paragraph)
          Backend::Connection.put(
            "/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/#{evaluator.file_name}", evaluator.file_content
          )
        end
      end
    end

    # Creates a package with three files: README.txt, <name>.spec and <name>.changes.
    factory :package_with_files do
      transient do
        file_name { 'README.txt' }
        file_content { Faker::Lorem.paragraph }
        spec_file_name { "#{name}.spec" }
        spec_file_content { Pathname.new(File.join('spec', 'fixtures', 'files', 'factory_package.spec')).read.gsub('factory_package', name) }
        changes_file_content { Pathname.new(File.join('spec', 'fixtures', 'files', 'factory_package.changes')).read }
        changes_file_name { "#{name}.changes" }
      end

      after(:create) do |package, evaluator|
        if CONFIG['global_write_through']
          Backend::Connection.put(
            "/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/#{evaluator.file_name}", evaluator.file_content
          )
          Backend::Connection.put(
            "/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/#{evaluator.spec_file_name}", evaluator.spec_file_content
          )
          Backend::Connection.put(
            "/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/#{evaluator.changes_file_name}", evaluator.changes_file_content
          )
        end
      end
    end

    factory :package_with_changes_file do
      transient do
        changes_file_content { Pathname.new(File.join('spec', 'fixtures', 'files', 'factory_package.changes')).read }
        changes_file_name { "#{name}.changes" }
      end

      after(:create) do |package, evaluator|
        if CONFIG['global_write_through']
          full_path = "/source/#{package.project.name}/#{package.name}/#{evaluator.changes_file_name}"
          Backend::Connection.put(Addressable::URI.escape(full_path), evaluator.changes_file_content)
        end
      end
    end

    factory :multibuild_package do
      transient do
        flavors { %w[flavor_a flavor_b] }
      end

      after(:create) do |package, evaluator|
        flavor_xml = evaluator.flavors.map { |flavor| "<flavor>#{flavor}</flavor>" }.join
        flavor_xml = "<multibuild>#{flavor_xml}</multibuild>"
        if CONFIG['global_write_through']
          Backend::Connection.put("/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/_config", Faker::Lorem.paragraph)
          Backend::Connection.put(
            "/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/_multibuild", flavor_xml
          )
        end
      end
    end

    factory :package_with_link do
      after(:create) do |package|
        target_package = create(:package_with_file, project: package.project)
        PackageKind.create(package_id: package.id, kind: 'link')

        file_content = "<link package=\"#{target_package}\" project=\"#{target_package.project}\" />"

        if CONFIG['global_write_through']
          Backend::Connection.put(
            "/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/_link", file_content
          )
        end
      end
    end

    factory :package_with_remote_link do
      transient do
        remote_project_name { Faker::Lorem.word }
        remote_package_name { Faker::Lorem.word }
      end
      after(:create) do |package, evaluator|
        PackageKind.create(package_id: package.id, kind: 'link')
        file_content = "<link package=\"#{evaluator.remote_package_name}\" project=\"#{evaluator.remote_project_name}\" />"

        if CONFIG['global_write_through']
          Backend::Connection.put(
            "/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/_link", file_content
          )
        end
      end
    end

    factory :package_with_binary do
      transient do
        target_file_name { 'bigfile_archive.tar.gz' }
        file_name { 'spec/fixtures/files/bigfile_archive.tar.gz' }
      end

      after(:create) do |package, evaluator|
        if CONFIG['global_write_through']
          Backend::Connection.put("/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/#{evaluator.target_file_name}",
                                  File.read(evaluator.file_name))
        end
      end
    end

    factory :package_with_binary_diff do
      after(:create) do |package|
        if CONFIG['global_write_through']
          Backend::Connection.put("/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/bigfile_archive.tar.gz",
                                  File.read('spec/fixtures/files/bigfile_archive.tar.gz'))

          # this is required to generate a diff - the backend treats binary files a bit different and only shows a diff if the
          # file has been changed.
          Backend::Connection.put("/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/bigfile_archive.tar.gz",
                                  File.read('spec/fixtures/files/bigfile_archive_2.tar.gz'))
        end
      end
    end

    factory :package_with_service do
      after(:create) do |package|
        if CONFIG['global_write_through']
          Backend::Connection.put(Addressable::URI.escape("/source/#{package.project.name}/#{package.name}/_service"),
                                  File.read('spec/fixtures/files/download_url_service.xml'))
        end
      end
    end

    factory :package_with_broken_service do
      after(:create) do |package|
        if CONFIG['global_write_through']
          Backend::Connection.put(Addressable::URI.escape("/source/#{package.project.name}/#{package.name}/_service"),
                                  '<service>broken</service>')
        end
      end
    end

    factory :package_with_kiwi_file do
      transient do
        kiwi_file_content do
          '<?xml version="1.0" encoding="UTF-8"?>
        <image name="Christians_openSUSE_13.2_JeOS" displayname="Christians_openSUSE_13.2_JeOS" schemaversion="5.2">
          <description type="system">
            <author>Christian Bruckmayer</author>
            <contact>noemail@example.com</contact>
            <specification>Tiny, minimalistic appliances</specification>
          </description>
          <preferences>
            <type image="docker" boot="grub"/>
            <version>2.0.0</version>
          </preferences>
        </image>'
        end
        kiwi_file_name { "#{name}.kiwi" }
      end

      after(:create) do |package, evaluator|
        if CONFIG['global_write_through']
          full_path = "/source/#{package.project.name}/#{package.name}/#{evaluator.kiwi_file_name}"
          Backend::Connection.put(Addressable::URI.escape(full_path), evaluator.kiwi_file_content)
        end
      end
    end

    factory :package_with_failed_comment_attribute do
      after(:create) do |package|
        create(:project_status_package_fail_comment_attrib, package: package)
      end
    end
  end
end
