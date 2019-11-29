module Kiwi
  class Image
    class XmlParser
      def initialize(xml_string, md5)
        @xml_document = Nokogiri::XML(xml_string)
        @md5 = md5
      end

      def parse
        return blank_image if @xml_document.xpath('image').blank?

        new_image = Kiwi::Image.new(name: @xml_document.xpath('image').attribute('name')&.value, md5_last_revision: @md5)

        new_image.use_project_repositories = use_project_repositories?
        new_image.repositories = repositories
        new_image.package_groups = package_groups
        new_image.description = description
        new_image.preferences = preferences
        new_image.profiles = profiles

        new_image
      end

      private

      def blank_image
        Kiwi::Image.new(name: 'New Image: Please provide a name', md5_last_revision: @md5)
      end

      def repositories_from_xml
        @repositories_from_xml ||= @xml_document.xpath('image/repository')
      end

      def use_project_repositories?
        repositories_from_xml.any? do |repository|
          repository.xpath('source').attribute('path')&.value == 'obsrepositories:/'
        end
      end

      # Return an array of Kiwi::Repository models from the parsed xml
      def repositories
        repositories_from_xml.reject { |repository| repository.xpath('source').attribute('path')&.value == 'obsrepositories:/' }.map.with_index(1) do |repository, index|
          attributes = {
            repo_type: repository.attribute('type')&.value,
            source_path: repository.xpath('source').attribute('path')&.value,
            priority: repository.attribute('priority')&.value,
            order: index,
            alias: repository.attribute('alias')&.value,
            replaceable: repository.attribute('status')&.value == 'replaceable',
            username: repository.attribute('username')&.value,
            password: repository.attribute('password')&.value
          }

          imageinclude = repository.attribute('imageinclude')&.value
          attributes['imageinclude'] = imageinclude == 'true' unless imageinclude.nil?
          prefer_license = repository.attribute('prefer-license')&.value
          attributes['prefer_license'] = prefer_license == 'true' unless prefer_license.nil?

          Kiwi::Repository.new(attributes)
        end
      end

      # Return an array of Kiwi::PackageGroup models, including their related Kiwi::Package models, from the parsed xml
      def package_groups
        package_groups = []

        @xml_document.xpath('image/packages').each do |package_group_xml|
          # FIXME: profiles should be Kiwi::Profile, not a string. It makes this easier to validate
          package_group = Kiwi::PackageGroup.new(
            kiwi_type: package_group_xml.attribute('type').value,
            profiles: package_group_xml.attribute('profiles')&.value,
            pattern_type: package_group_xml.attribute('patternType')&.value
          )

          package_group_xml.xpath('package').each do |package_xml|
            attributes = {
              name: package_xml.attribute('name').value,
              arch: package_xml.attribute('arch')&.value,
              replaces: package_xml.attribute('replaces')&.value
            }

            bootinclude = package_xml.attribute('bootinclude')&.value
            attributes['bootinclude'] = bootinclude == 'true' unless bootinclude.nil?
            bootdelete = package_xml.attribute('bootdelete')&.value
            attributes['bootdelete'] = bootdelete == 'true' unless bootdelete.nil?

            package_group.packages.build(attributes)
          end

          package_groups << package_group
        end

        package_groups
      end

      # Return an instance of Kiwi::Description model from the parsed xml
      def description
        description_element = @xml_document.xpath('image/description[@type="system"]').first
        return if description_element.blank?

        Kiwi::Description.new(
          description_type: description_element.attribute('type')&.value.to_s,
          author: description_element.xpath('author')&.text,
          contact: description_element.xpath('contact')&.text,
          specification: description_element.xpath('specification')&.text
        )
      end

      def preferences
        preference_elements = @xml_document.xpath('image/preferences')
        return [] if preference_elements.blank?

        preference_elements.map do |preference_element|
          Kiwi::Preference.new(
            type_image: preference_type_image(preference_element),
            version: preference_element.xpath('version')&.text,
            type_containerconfig_name: preference_type_containerconfig(preference_element, 'name'),
            type_containerconfig_tag: preference_type_containerconfig(preference_element, 'tag'),
            # The profile is a string since creating association between new preferences/profiles is not possible
            profile: preference_element.attribute('profiles')&.value
          )
        end
      end

      def preference_type_image(preference)
        preference_type = preference.xpath('type')
        return if preference_type.blank?

        preference_type.attribute('image')&.value
      end

      def preference_type_containerconfig(preference, attribute)
        preference_containerconfig = preference.xpath('type/containerconfig')
        return if preference_containerconfig.blank?

        preference_containerconfig.attribute(attribute)&.value
      end

      def profiles
        profile_elements = @xml_document.xpath('image/profiles/profile')

        return [] if profile_elements.blank?

        selected_profiles = @xml_document.xpath('/comment()[contains(., "OBS-Profiles:")]')[0]&.text || ''

        profile_elements.map do |profile_element|
          Kiwi::Profile.new(
            name: profile_element.attribute('name').value,
            description: profile_element.attribute('description').value,
            selected: selected_profiles.match?(" #{profile_element.attribute('name').value} ")
          )
        end
      end
    end
  end
end
