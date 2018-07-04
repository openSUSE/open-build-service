FactoryBot.define do
  factory :package do
    project
    sequence(:name) { |n| "package_#{n}" }
    title { Faker::Book.title }
    description { Faker::Lorem.sentence }

    after(:create) do |package|
      # NOTE: Enable global write through when writing new VCR cassetes.
      # ensure the backend knows the project
      package.write_to_backend
    end

    factory :package_with_revisions do
      transient do
        revision_count 2
      end

      after(:create) do |package, evaluator|
        evaluator.revision_count.times do |i|
          if CONFIG['global_write_through']
            Backend::Connection.put("/source/#{package.project}/#{package}/somefile.txt", i.to_s)
          end
        end
      end
    end

    factory :package_with_file do
      transient do
        file_content Faker::Lorem.paragraph
      end

      after(:create) do |package, evaluator|
        # NOTE: Enable global write through when writing new VCR cassetes.
        # ensure the backend knows the project
        if CONFIG['global_write_through']
          Backend::Connection.put("/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/_config", Faker::Lorem.paragraph)
          Backend::Connection.put("/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/somefile.txt", evaluator.file_content)
        end
      end
    end

    factory :package_with_binary do
      transient do
        target_file_name 'bigfile_archive.tar.gz'
        file_name 'spec/support/files/bigfile_archive.tar.gz'
      end

      after(:create) do |package, evaluator|
        if CONFIG['global_write_through']
          Backend::Connection.put("/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/#{evaluator.target_file_name}",
                                  File.open(evaluator.file_name).read)
        end
      end
    end

    factory :package_with_binary_diff do
      after(:create) do |package|
        if CONFIG['global_write_through']
          Backend::Connection.put("/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/bigfile_archive.tar.gz",
                                  File.open('spec/support/files/bigfile_archive.tar.gz').read)

          # this is required to generate a diff - the backend treats binary files a bit different and only shows a diff if the
          # file has been changed.
          Backend::Connection.put("/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/bigfile_archive.tar.gz",
                                  File.open('spec/support/files/bigfile_archive_2.tar.gz').read)
        end
      end
    end

    factory :package_with_service do
      after(:create) do |package|
        # NOTE: Enable global write through when writing new VCR cassetes.
        # ensure the backend knows the project
        if CONFIG['global_write_through']
          Backend::Connection.put("/source/#{URI.escape(package.project.name)}/#{URI.escape(package.name)}/_service", '<services/>')
        end
      end
    end

    factory :package_with_broken_service do
      after(:create) do |package|
        # NOTE: Enable global write through when writing new VCR cassetes.
        # ensure the backend knows the project
        if CONFIG['global_write_through']
          Backend::Connection.put("/source/#{URI.escape(package.project.name)}/#{URI.escape(package.name)}/_service", '<service>broken</service>')
        end
      end
    end

    factory :package_with_changes_file do
      transient do
        changes_file_content '
-------------------------------------------------------------------
Fri Aug 11 16:58:15 UTC 2017 - tom@opensuse.org

- Testing the submit diff

-------------------------------------------------------------------
Wed Aug  2 14:59:15 UTC 2017 - iggy@opensuse.org

- Temporary hack'
        changes_file_name { "#{name}.changes" }
      end

      after(:create) do |package, evaluator|
        # NOTE: Enable global write through when writing new VCR cassetes.
        # ensure the backend knows the project
        if CONFIG['global_write_through']
          full_path = "/source/#{package.project.name}/#{package.name}/#{evaluator.changes_file_name}"
          Backend::Connection.put(URI.escape(full_path), evaluator.changes_file_content)
        end
      end
    end

    factory :package_with_kiwi_file do
      transient do
        kiwi_file_content '<?xml version="1.0" encoding="UTF-8"?>
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
        kiwi_file_name { "#{name}.kiwi" }
      end

      after(:create) do |package, evaluator|
        # NOTE: Enable global write through when writing new VCR cassetes.
        # ensure the backend knows the project
        if CONFIG['global_write_through']
          full_path = "/source/#{package.project.name}/#{package.name}/#{evaluator.kiwi_file_name}"
          Backend::Connection.put(URI.escape(full_path), evaluator.kiwi_file_content)
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
