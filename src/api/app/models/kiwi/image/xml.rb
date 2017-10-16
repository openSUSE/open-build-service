# TODO: Please overwrite this comment with something explaining the model target
module Kiwi
  class Image
    class Xml
      def initialize(image)
        @image = image
      end

      def to_xml
        doc = Nokogiri::XML::DocumentFragment.parse(kiwi_body)
        image = doc.at_css('image')

        return nil unless image && image.first_element_child

        doc = update_packages(doc)
        doc = update_repositories(doc)
        Nokogiri::XML(doc.to_xml, &:noblanks).to_xml(indent: kiwi_indentation(doc))
      end

      private

      def update_packages(document)
        # for now we only write the default package group
        xml_packages = @image.default_package_group.to_xml
        packages = document.xpath('image/packages[@type="image"]').first
        if packages
          packages.replace(xml_packages)
        else
          document.at_css('image').last_element_child.after(xml_packages)
        end
        document
      end

      def update_repositories(document)
        repository_position = document.xpath("image/repository").first.try(:previous) || document.at_css('image').last_element_child
        document.xpath("image/repository").remove
        xml_repos = repositories_for_xml.map(&:to_xml).join("\n")
        repository_position.after(xml_repos)
        document
      end

      def repositories_for_xml
        if @image.use_project_repositories?
          [Kiwi::Repository.new(source_path: 'obsrepositories:/', repo_type: 'rpm-md')]
        else
          @image.repositories
        end
      end

      def kiwi_body
        if @image.package
          kiwi_file = @image.package.kiwi_image_file
          return nil unless kiwi_file
          @image.package.source_file(kiwi_file)
        else
          Kiwi::Image::DEFAULT_KIWI_BODY
        end
      end

      def kiwi_indentation(xml)
        content = xml.xpath('image').children.first.try(:content)
        content ? content.delete("\n").length : 2
      end
    end
  end
end
