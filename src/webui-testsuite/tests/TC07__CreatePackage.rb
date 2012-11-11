# -*- coding: utf-8 -*-
# encoding: utf-8

class TC07__CreatePackage < TestCase


  test :create_home_project_package_for_user do
  depend_on :create_home_project_for_user
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_new_package
    create_package(
      :name => "HomePackage1",
      :title => "Title for HomePackage1", 
      :description => "Empty home project package created by #{current_user[:login]}.")
  end


  test :create_home_project_package_for_second_user do
  depend_on :create_home_project_for_second_user
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user2],
      :project => "home:user2"
    open_new_package
    create_package(
      :name => "Home2Package1",
      :title => "Title for Home2Package1", 
      :description => "Empty home project package created by #{current_user[:login]}.")
  end



  test :create_subproject_package_for_user do
  depend_on :create_subproject_for_user

    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1:SubProject1"
    open_new_package
    create_package(
      :name => "SubPackage1",
      :title => "Title for SubPackage1", 
      :description => "Empty subproject package created by #{current_user[:login]}.")
  end


  test :create_global_project_package do
  depend_on :create_global_project

    navigate_to ProjectOverviewPage,
      :user => $data[:admin],
      :project => "PublicProject1"
    open_new_package
    create_package(
      :name => "PublicPackage1",
      :title => "Title for PublicPackage1", 
      :description => "Empty public project package created by #{current_user[:login]}.")
  end


  test :create_package_without_name do
  depend_on :create_home_project_for_user
    
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_new_package
    create_package(
      :name => "",
      :title => "Title for HomePackage1", 
      :description => "Empty home project package without name. Must fail.",
      :expect => :invalid_name)
  end
  
  
  test :create_package_name_with_spaces do
  depend_on :create_home_project_for_user
  
      navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_new_package
    create_package(
      :name => "invalid package name",
      :description => "Empty home project package with invalid name. Must fail.",
      :expect => :invalid_name)
  end

  
  test :create_package_with_only_name do
  depend_on :create_home_project_for_user
  
      navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_new_package
    create_package(
      :name => "HomePackage-OnlyName",
      :description => "")
  end

  
  test :create_package_with_long_description do
  depend_on :create_home_project_for_user
    
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_new_package
    create_package(
      :name => "HomePackage-LongDesc",
      :title => "Title for HomePackage-LongDesc", 
      :description => LONG_DESCRIPTION)
  end

  
  test :create_package_duplicate_name do
  depend_on :create_home_project_package_for_user
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_new_package
    create_package(
      :name => "HomePackage1",
      :title => "Title for HomePackage1", 
      :description => "Empty home project package created by #{current_user[:login]}.",
      :expect => :already_exists)
  end
  
  test :create_package_strange_name do
    depend_on :create_home_project_package_for_user
    navigate_to ProjectOverviewPage,
       user: $data[:user1],
       project: "home:user1"
    open_new_package
    create_package name: "Testing包صفقة", expect: :invalid_name

    create_package name: "Cplus+"
    packageurl = $page.current_url
    navigate_to ProjectOverviewPage,  project: "home:user1"
    wait_for_javascript
    foundcplus=nil
    $page.driver.find_elements(css: "#packages_table a").each do |link|
       next unless link.text == 'Cplus+'
       foundcplus=link.attribute('href')	
       break
    end
    assert !foundcplus.nil?
    assert_equal packageurl, foundcplus
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
