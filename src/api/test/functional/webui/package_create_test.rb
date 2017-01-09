# -*- coding: utf-8 -*-
require_relative '../../test_helper'

class Webui::PackageCreateTest < Webui::IntegrationTest
  setup do
    @project = 'home:Iggy'
  end

  def open_new_package
    click_link('Create package')
    page.must_have_text 'Create New Package for '
  end

  def create_package(new_package)
    new_package[:expect]      ||= :success
    new_package[:name]        ||= ''
    new_package[:title]       ||= ''
    new_package[:description] ||= ''

    new_package[:description].squeeze!(' ')
    new_package[:description].gsub!(/ *\n +/, "\n")
    new_package[:description].strip!
    message_prefix = "Package '#{new_package[:name]}' "

    fill_in 'name', with: new_package[:name]
    fill_in 'title', with: new_package[:title]
    fill_in 'description', with: new_package[:description]

    click_button('Save changes')

    if new_package[:expect] == :success
      flash_message.must_equal message_prefix + 'was created successfully'
      flash_message_type.must_equal :info
      new_package[:description] = 'No description set' if new_package[:description].empty?
      assert_equal new_package[:description].gsub(%r{\s+}, ' '), find(:id, 'description-text').text
    elsif new_package[:expect] == :invalid_name
      flash_message.must_equal "Invalid package name: '#{new_package[:name]}'"
      flash_message_type.must_equal :alert
      page.must_have_text 'Create New Package for '
    elsif new_package[:expect] == :already_exists
      flash_message.must_equal message_prefix + "already exists in project '#{@project}'"
      flash_message_type.must_equal :alert
      page.must_have_text 'Create New Package for '
    else
      throw 'Invalid value for argument expect(must be :success, :invalid_name, :already_exists)'
    end
  end

  def test_create_home_project_package_for_user # spec/features/webui/projects_spec.rb
    use_js
    login_Iggy to: project_show_path(project: 'home:Iggy')
    open_new_package
    create_package(
      name: 'HomePackage1',
      title: 'Title for HomePackage1',
      description: 'Empty home project package created')

    # now check duplicated name
    visit project_show_path(project: 'home:Iggy')
    open_new_package
    create_package(
      name: 'HomePackage1',
      title: 'Title for HomePackage1',
      description: 'Empty home project package created',
      expect: :already_exists)

    # tear down
    delete_package('home:Iggy', 'HomePackage1')
  end

  def test_create_global_project_package # spec/features/webui/projects_spec.rb
    use_js
    login_king to: project_show_path(project: 'LocalProject')

    open_new_package
    create_package(
      name: 'PublicPackage1',
      title: 'Title for PublicPackage1',
      description: 'Empty public project package created')
    # tear down
    delete_package('LocalProject', 'PublicPackage1')
  end

  def test_create_package_without_name # spec/features/webui/projects_spec.rb
    login_Iggy to: project_show_path(project: 'home:Iggy')

    open_new_package
    create_package(
      name: '',
      title: 'Title for HomePackage1',
      description: 'Empty home project package without name. Must fail.',
      expect: :invalid_name)
  end

  def test_create_package_name_with_spaces # spec/features/webui/projects_spec.rb
    login_Iggy to: project_show_path(project: 'home:Iggy')

    open_new_package
    create_package(
      name: 'invalid package name',
      description: 'Empty home project package with invalid name. Must fail.',
      expect: :invalid_name)
  end

  def test_create_package_with_only_name # spec/features/webui/projects_spec.rb
    use_js
    login_Iggy to: project_show_path(project: 'home:Iggy')

    open_new_package
    create_package(
      name: 'HomePackage-OnlyName',
      description: '')
    # tear down
    delete_package('home:Iggy', 'HomePackage-OnlyName')
  end

  def test_create_package_with_long_description # spec/features/webui/projects_spec.rb
    use_js

    login_Iggy to: project_show_path(project: 'home:Iggy')

    open_new_package
    create_package(
      name: 'HomePackage-LongDesc',
      title: 'Title for HomePackage-LongDesc',
      description: LONG_DESCRIPTION)

    # tear down
    delete_package('home:Iggy', 'HomePackage-LongDesc')
  end

  def test_create_package_strange_name # spec/features/webui/projects_spec.rb
    use_js
    login_Iggy to: project_show_path(project: 'home:Iggy')

    open_new_package
    create_package name: 'Testing包صفقةäölü', expect: :invalid_name

    create_package name: 'Cplus+'
    packageurl = page.current_url
    visit project_show_path( project: 'home:Iggy')

    baseuri = URI.parse(page.current_url)
    foundcplus = nil
    page.all('#raw_packages a').each do |link|
      next unless link.text == 'Cplus+'
      foundcplus = baseuri.merge(link['href']).to_s
      break
    end
    assert !foundcplus.nil?
    foundcplus.must_equal packageurl

    # tear down
    delete_package('home:Iggy', 'Cplus+')
  end

  # RUBY CODE ENDS HERE.
  # BELOW ARE APPENDED ALL DATA STRUCTURES USED BY THE TESTS.

# -------------------------------------------------------------------------------------- #
LONG_DESCRIPTION = <<LICENSE_END
        GNU GENERAL PUBLIC LICENSE
           Version 2, June 1991

 Copyright (C) 1989, 1991 Free Software Foundation, Inc.
 51 Franklin Steet, Fifth Floor, Boston, MA  02111-1307  USA
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.

          Preamble

  The licenses for most software are designed to take away your
freedom to share and change it.  By contrast, the GNU General Public
License is intended to guarantee your freedom to share and change free
software--to make sure the software is free for all its users.  This
General Public License applies to most of the Free Software
Foundation's software and to any other program whose authors commit to
using it.  (Some other Free Software Foundation software is covered by
the GNU Library General Public License instead.)  You can apply it to
your programs, too.

  When we speak of free software, we are referring to freedom, not
price.  Our General Public Licenses are designed to make sure that you
have the freedom to distribute copies of free software (and charge for
this service if you wish), that you receive source code or can get it
if you want it, that you can change the software or use pieces of it
in new free programs; and that you know you can do these things.

  To protect your rights, we need to make restrictions that forbid
anyone to deny you these rights or to ask you to surrender the rights.
These restrictions translate to certain responsibilities for you if you
distribute copies of the software, or if you modify it.

  For example, if you distribute copies of such a program, whether
gratis or for a fee, you must give the recipients all the rights that
you have.  You must make sure that they, too, receive or can get the
source code.  And you must show them these terms so they know their
rights.

  We protect your rights with two steps: (1) copyright the software, and
(2) offer you this license which gives you legal permission to copy,
distribute and/or modify the software.

  Also, for each author's protection and ours, we want to make certain
that everyone understands that there is no warranty for this free
software.  If the software is modified by someone else and passed on, we
want its recipients to know that what they have is not the original, so
that any problems introduced by others will not reflect on the original
authors' reputations.

  Finally, any free program is threatened constantly by software
patents.  We wish to avoid the danger that redistributors of a free
program will individually obtain patent licenses, in effect making the
program proprietary.  To prevent this, we have made it clear that any
patent must be licensed for everyone's free use or not licensed at all.

  The precise terms and conditions for copying, distribution and
modification follow.

        GNU GENERAL PUBLIC LICENSE
   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

  0. This License applies to any program or other work which contains
a notice placed by the copyright holder saying it may be distributed
under the terms of this General Public License.  The "Program", below,
refers to any such program or work, and a "work based on the Program"
means either the Program or any derivative work under copyright law:
that is to say, a work containing the Program or a portion of it,
either verbatim or with modifications and/or translated into another
language.  (Hereinafter, translation is included without limitation in
the term "modification".)  Each licensee is addressed as "you".

Activities other than copying, distribution and modification are not
covered by this License; they are outside its scope.  The act of
running the Program is not restricted, and the output from the Program
is covered only if its contents constitute a work based on the
Program (independent of having been made by running the Program).
Whether that is true depends on what the Program does.

  1. You may copy and distribute verbatim copies of the Program's
source code as you receive it, in any medium, provided that you
conspicuously and appropriately publish on each copy an appropriate
copyright notice and disclaimer of warranty; keep intact all the
notices that refer to this License and to the absence of any warranty;
and give any other recipients of the Program a copy of this License
along with the Program.
LICENSE_END
# -------------------------------------------------------------------------------------- #
end
