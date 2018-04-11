# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'
require 'json'

class PatchinfoTest < ActiveSupport::TestCase
  fixtures :all

  def test_valid_patchinfo
    content = "<patchinfo incident='123'>
                 <category>security</category>
                 <issue id='123' tracker='bnc' />
                 <rating>moderate</rating>
                 <packager>Iggy</packager>
                 <description>blah
blub
                 </description>
                 <summary>Security update for someone</summary>
               </patchinfo>"
    Patchinfo.new.verify_data(Project.first, content)
  end

  def test_invalid_patchinfo_packager
    content = "<patchinfo incident='123'>
                 <issue id='CVE-2016-INVALID' tracker='cve' />
                 <category>security</category>
                 <rating>moderate</rating>
                 <packager>someone</packager>
                 <description>blah
blub
                 </description>
                 <summary>Security update for someone</summary>
               </patchinfo>"
    assert_raise NotFoundError do
      Patchinfo.new.verify_data(Project.first, content)
    end
  end

  def test_invalid_patchinfo_cve_entry
    content = "<patchinfo incident='123'>
                 <issue id='CVE-2016-INVALID' tracker='cve' />
                 <category>security</category>
                 <rating>moderate</rating>
                 <packager>Iggy</packager>
                 <description>blah
blub
                 </description>
                 <summary>Security update for someone</summary>
               </patchinfo>"
    assert_raise IssueTracker::InvalidIssueName do
      Patchinfo.new.verify_data(Project.first, content)
    end
  end

  def test_invalid_patchinfo_tracker
    content = "<patchinfo incident='123'>
                 <issue id='123' tracker='INVALID' />
                 <category>security</category>
                 <rating>moderate</rating>
                 <packager>Iggy</packager>
                 <description>blah
blub
                 </description>
                 <summary>Security update for someone</summary>
               </patchinfo>"
    assert_raise Patchinfo::TrackerNotFound do
      Patchinfo.new.verify_data(Project.first, content)
    end
  end
end
