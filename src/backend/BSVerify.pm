#
# Copyright (c) 2006, 2007 Michael Schroeder, Novell Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file COPYING); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
################################################################
#
# parameter verification functions
#

package BSVerify;

use strict;

# keep in sync with src/api/app/model/project.rb
sub verify_projid {
  my $projid = $_[0];
  die("projid is empty\n") unless defined($projid) && $projid ne '';
  die("projid '$projid' is illegal\n") if $projid =~ /[\/\000-\037]/;
  die("projid '$projid' is illegal\n") if ":$projid:" =~ /:[_\.:]/;
  die("projid '$projid' is too long\n") if length($projid) > 200;
}

sub verify_projkind {
  my $projkind = $_[0];
  die("projkind '$projkind' is illegal\n") if $projkind ne 'standard' && $projkind ne 'maintenance' && $projkind ne 'maintenance_incident' && $projkind ne 'maintenance_release'
}

# keep in sync with src/api/app/model/package.rb
sub verify_packid {
  my $packid = $_[0];
  die("packid is empty\n") unless defined($packid) && $packid ne '';
  $packid =~ s/^_product://s;
  $packid =~ s/^_patchinfo://s;
  die("packid '$packid' is illegal\n") if $packid =~ /[\/:\000-\037]/;
  die("packid '$packid' is illegal\n") if $packid =~ /^[_\.]/ && $packid ne '_product' && $packid ne '_pattern' && $packid ne '_project' && $packid ne '_patchinfo';
  die("packid '$packid' is too long\n") if length($packid) > 200;
}

sub verify_repoid {
  my $repoid = $_[0];
  die("repoid is empty\n") unless defined($repoid) && $repoid ne '';
  die("repoid '$repoid' is illegal\n") if $repoid =~ /[\/:\000-\037]/;
  die("repoid '$repoid' is illegal\n") if $repoid =~ /^[_\.]/;
  die("repoid '$repoid' is too long\n") if length($repoid) > 200;
}

sub verify_jobid {
  my $jobid = $_[0];
  die("jobid is empty\n") unless defined($jobid) && $jobid ne '';
  die("jobid '$jobid' is illegal\n") if $jobid =~ /[\/\000-\037]/;
  die("jobid '$jobid' is illegal\n") if $jobid =~ /^[\.]/;
}

sub verify_arch {
  my $arch = $_[0];
  die("arch is empty\n") unless defined($arch) && $arch ne '';
  die("arch '$arch' is illegal\n") if $arch =~ /[\/:\.\000-\037]/;
  die("arch '$arch' is too long\n") if length($arch) > 200;
  verify_simple($arch);
}

sub verify_packid_repository {
  verify_packid($_[0]) unless $_[0] && $_[0] eq '_repository';
}

sub verify_patchinfo {
  # This verifies the absolute minimum required content of a patchinfo file
  my $p = $_[0];
  verify_filename($p->{'name'}) if defined($p->{'name'});
  my %allowed_categories = map {$_ => 1} qw{security recommended optional feature};
  die("Invalid category defined in _patchinfo\n") if defined($p->{'category'}) && !$allowed_categories{$p->{'category'}};
  for my $rt (@{$p->{'releasetarget'} || []}) {
    verify_projid($rt->{'project'});
    verify_repoid($rt->{'repository'}) if defined $rt->{'repository'};
  }
}

sub verify_patchinfo_complete {
  # This verifies all necessary content to create a patchinfo repo
  my $p = $_[0];
  verify_patchinfo( $p );
#  die("No bugzilla id defined in _patchinfo") unless $p->{'bugzilla'};
#  for my $id (@{$p->{'bugzilla'}}){
#    die("Invalid bugzilla ID in _patchinfo") unless $id->{'_content'} =~ /^[0-9]+$/;
#  }
  die("No summary defined in _patchinfo") unless $p->{'summary'};
  die("No description defined in _patchinfo") unless $p->{'description'};
  my %allowed_categories = map {$_ => 1} qw{security recommended optional feature};
  die("No category defined in _patchinfo") unless $p->{'category'};
  die("Invalid category defined in _patchinfo") unless !$allowed_categories{$p->{'category'}};
  for my $binary (@{$p->{'binary'}||[]}) {
    verify_filename($binary);
  }

  # checks of optional content to be added here
}

sub verify_simple {
  my $name = $_[0];
  die("illegal characters\n") if $name =~ /[^\-+=\.,0-9:%{}\@#%A-Z_a-z~\200-\377]/s;
}

sub verify_filename {
  my $filename = $_[0];
  die("filename is empty\n") unless defined($filename) && $filename ne '';
  die("filename '$filename' is illegal\n") if $filename =~ /[\/\000-\037]/;
  die("filename '$filename' is illegal\n") if $filename =~ /^\./;
}

sub verify_md5 {
  my $md5 = $_[0];
  die("not a md5 sum\n") unless $md5 && $md5 =~ /^[0-9a-f]{32}$/s;
}

sub verify_rev {
  my $rev = $_[0];
  die("revision is empty\n") unless defined($rev) && $rev ne '';
  return if $rev =~ /^[0-9a-f]{32}$/s;
  return if $rev =~ /^[0-9a-f]{40}$/s;	# git id
  return if $rev eq 'upload' || $rev eq 'build' || $rev eq 'latest' || $rev eq 'repository';
  die("bad revision '$rev'\n") unless $rev =~ /^\d+$/s;
}

sub verify_linkrev {
  my $rev = $_[0];
  return if $rev && $rev eq 'base';
  verify_rev($rev);
}

sub verify_port {
  my $port = $_[0];
  die("port is empty\n") unless defined($port) && $port ne '';
  die("bad port '$port'\n") unless $port =~ /^\d+$/s;
  die("illegal port '$port'\n") unless $port >= 1024;
}

sub verify_num {
  my $num = $_[0];
  die("number is empty\n") unless defined($num) && $num ne '';
  die("not a number: '$num'\n") unless $num =~ /^\d+$/;
}

sub verify_intnum {
  my $num = $_[0];
  die("number is empty\n") unless defined($num) && $num ne '';
  die("not a number: '$num'\n") unless $num =~ /^-?\d+$/;
}

sub verify_bool {
  my $bool = $_[0];
  die("not boolean\n") unless defined($bool) && ($bool eq '0' || $bool eq '1');
}

sub verify_prp {
  my $prp = $_[0];
  die("not a prp: '$prp'\n") unless $prp =~ /^([^\/]*)\/(.*)$/s;
  my ($projid, $repoid) = ($1, $2);
  verify_projid($projid);
  verify_repoid($repoid);
}

sub verify_prpa {
  my $prpa = $_[0];
  die("not a prpa: '$prpa'\n") unless $prpa =~ /^(.*)\/([^\/]*)$/s;
  my ($prp, $arch) = ($1, $2);
  verify_prp($prp);
  verify_arch($arch);
}

sub verify_resultview {
  my $view = $_[0];
  die("unknown view parameter: '$view'\n") if $view ne 'summary' && $view ne 'status' && $view ne 'binarylist' && $view ne 'stats';
}

sub verify_disableenable {
  my ($disen) = @_;
  for my $d (@{$disen->{'disable'} || []}, @{$disen->{'enable'} || []}) {
    verify_repoid($d->{'repository'}) if exists $d->{'repository'};
    verify_arch($d->{'arch'}) if exists $d->{'arch'};
  }
}

sub verify_proj {
  my ($proj, $projid) = @_;
  if (defined($projid)) {
    die("name does not match data\n") unless $projid eq $proj->{'name'};
  }
  verify_projid($proj->{'name'});
  verify_projkind($proj->{'kind'}) if exists $proj->{'kind'};
  my %got_pack;
  for my $pack (@{$proj->{'package'} || []}) {
    verify_packid($pack->{'name'});
    die("package $pack->{'name'} listed more than once\n") if $got_pack{$pack->{'name'}};
    $got_pack{$pack->{'name'}} = 1;
  }
  my %got;
  for my $repo (@{$proj->{'repository'} || []}) {
    verify_repoid($repo->{'name'});
    die("repository $repo->{'name'} listed more than once\n") if $got{$repo->{'name'}};
    $got{$repo->{'name'}} = 1;
    for my $r (@{$repo->{'path'} || []}) {
      verify_projid($r->{'project'});
      verify_repoid($r->{'repository'});
    }
    for my $a (@{$repo->{'arch'} || []}) {
      verify_arch($a);
    }
    for my $rt (@{$repo->{'releasetarget'} || []}) {
      verify_projid($rt->{'project'});
      verify_repoid($rt->{'repository'});
    }
  }
  for my $link (@{$proj->{'link'} || []}) {
    verify_projid($link->{'project'});
  }
  for my $f ('build', 'publish', 'debuginfo', 'useforbuild') {
    verify_disableenable($proj->{$f}) if $proj->{$f};
  }
  die('project must not have mountproject\n') if exists $proj->{'mountproject'};
  if ($proj->{'maintenance'}) {
    for my $m (@{$proj->{'maintenance'}->{'maintains'} || []}) {
      verify_projid($m->{'project'});
    }
  }
}

sub verify_pack {
  my ($pack, $packid) = @_;
  if (defined($packid)) {
    die("name does not match data\n") unless $packid eq $pack->{'name'};
  }
  verify_packid($pack->{'name'});
  verify_disableenable($pack);	# obsolete
  for my $f ('build', 'debuginfo', 'useforbuild', 'publish') {
    verify_disableenable($pack->{$f}) if $pack->{$f};
  }
  if ($pack->{'devel'}) {
    verify_projid($pack->{'devel'}->{'project'}) if exists $pack->{'devel'}->{'project'};
    verify_packid($pack->{'devel'}->{'package'}) if exists $pack->{'devel'}->{'package'};
  }
}

sub verify_link {
  my ($l) = @_;
  verify_projid($l->{'project'}) if exists $l->{'project'};
  verify_packid($l->{'package'}) if exists $l->{'package'};
  verify_rev($l->{'rev'}) if exists $l->{'rev'};
  verify_rev($l->{'baserev'}) if exists $l->{'baserev'};
  verify_simple($l->{'vrev'}) if defined $l->{'vrev'};
  die("link must contain some target description \n") unless exists $l->{'project'} || exists $l->{'package'} || exists $l->{'rev'};
  if (exists $l->{'cicount'}) {
    if ($l->{'cicount'} ne 'add' && $l->{'cicount'} ne 'copy' && $l->{'cicount'} ne 'local') {
      die("unknown cicount '$l->{'cicount'}'\n");
    }
  }
  if (exists $l->{'missingok'}) {
    die("missingok in link must be '1' or 'true'\n") unless $l->{'missingok'} && ($l->{'missingok'} eq '1' || $l->{'missingok'} eq 'true');
  }
  return unless $l->{'patches'} && $l->{'patches'}->{''};
  for my $p (@{$l->{'patches'}->{''}}) {
    die("more than one type in patch\n") unless keys(%$p) == 1;
    my $type = (keys %$p)[0];
    my $pd = $p->{$type};
    if ($type eq 'branch') {
      die("branch link must have baserev\n") unless $l->{'baserev'};
      die("branch link must not have other patches\n") if @{$l->{'patches'}->{''}} != 1;
      die("branch element contains data\n") if $pd;
    } elsif ($type eq 'add' || $type eq 'apply' || $type eq 'delete') {
      verify_filename($pd->{'name'});
    } elsif ($type ne 'topadd') {
      die("unknown patch type '$type'\n");
    }
  }
}

sub verify_aggregatelist {
  my ($al) = @_;
  for my $a (@{$al->{'aggregate'} || []}) {
    verify_projid($a->{'project'});
    if (defined($a->{'nosources'})) {
      die("'nosources' element must be empty\n") if $a->{'nosources'} ne '';
    }
    for my $p (@{$a->{'package'} || []}) {
      verify_packid($p);
    }
    for my $b (@{$a->{'binary'} || []}) {
      verify_filename($b);
    }
    for my $r (@{$a->{'repository'} || []}) {
      verify_repoid($r->{'source'}) if exists $r->{'source'};
      verify_repoid($r->{'target'}) if exists $r->{'target'};
    }
  }
}

my %req_states = map {$_ => 1} qw {new revoked accepted superseded declined deleted review};

sub verify_request {
  my ($req) = @_;
  die("request must not contain a key\n") if exists $req->{'key'};
  verify_num($req->{'id'}) if exists $req->{'id'};
  die("request must contain a state\n") unless $req->{'state'};
  die("request must contain a state name\n") unless $req->{'state'}->{'name'};
  die("request must contain a state who\n") unless $req->{'state'}->{'who'};
  die("request must contain a state when\n") unless $req->{'state'}->{'when'};
  die("request contains unknown state '$req->{'state'}->{'name'}'\n") unless $req_states{$req->{'state'}->{'name'}};
  verify_num($req->{'state'}->{'superseded_by'}) if exists $req->{'state'}->{'superseded_by'};

  my $actions;
  if ($req->{'type'}) {
    die("unknown old-stype request type\n") unless $req->{'type'} eq 'submit';
    die("old-stype request with action element\n") if $req->{'action'};
    die("old-stype request without submit element\n") unless $req->{'submit'};
    my %oldsubmit = (%{$req->{'submit'}}, 'type' => 'submit');
    $actions = [ \%oldsubmit ];
  } else {
    die("new-stype request with submit element\n") if $req->{'submit'};
    $actions = $req->{'action'};
  }
  die("request must contain an action\n") unless $actions && @$actions;
  my %pkgchange;
  for my $h (@{$req->{'history'} ||[]}) {
    die("history element has no 'who' attribute\n") unless $h->{'who'};
    die("history element has no 'when' attribute\n") unless $h->{'when'};
    die("history element has no 'name' attribute\n") unless $h->{'name'};
  }
  for my $r (@$actions) {
    die("request action has no type\n") unless $r->{'type'};
    if ($r->{'type'} eq 'delete') {
      die("delete target specification missing\n") unless $r->{'target'};
      die("delete target project specification missing\n") unless $r->{'target'}->{'project'};
      verify_projid($r->{'target'}->{'project'});
      verify_packid($r->{'target'}->{'package'}) if exists $r->{'target'}->{'package'};
      die("delete action has a source element\n") if $r->{'source'};
    } elsif ($r->{'type'} eq 'maintenance_release') {
      die("maintenance_release source missing\n") unless $r->{'source'};
      die("maintenance_release target missing\n") unless $r->{'target'};
      verify_projid($r->{'source'}->{'project'});
      verify_projid($r->{'target'}->{'project'});
    } elsif ($r->{'type'} eq 'maintenance_incident') {
      die("maintenance_incident source missing\n") unless $r->{'source'};
      die("maintenance_incident target missing\n") unless $r->{'target'};
      verify_projid($r->{'source'}->{'project'});
      verify_projid($r->{'target'}->{'project'});
    } elsif ($r->{'type'} eq 'set_bugowner') {
      die("set_bugowner target missing\n") unless $r->{'target'};
      verify_projid($r->{'target'}->{'project'});
      verify_packid($r->{'target'}->{'package'}) if exists $r->{'target'}->{'package'};
    } elsif ($r->{'type'} eq 'add_role') {
      die("add_role target missing\n") unless $r->{'target'};
      verify_projid($r->{'target'}->{'project'});
      verify_packid($r->{'target'}->{'package'}) if exists $r->{'target'}->{'package'};
    } elsif ($r->{'type'} eq 'change_devel') {
      die("change_devel source missing\n") unless $r->{'source'};
      die("change_devel target missing\n") unless $r->{'target'};
      die("change_devel source with rev attribute\n") if exists $r->{'source'}->{'rev'};
      verify_projid($r->{'source'}->{'project'});
      verify_projid($r->{'target'}->{'project'});
      verify_packid($r->{'source'}->{'package'}) if exists $r->{'source'}->{'package'};
      verify_packid($r->{'target'}->{'package'});
    } elsif ($r->{'type'} eq 'submit') {
      die("submit source missing\n") unless $r->{'source'};
      die("submit target missing\n") unless $r->{'target'};
      verify_projid($r->{'source'}->{'project'});
      verify_projid($r->{'target'}->{'project'});
      verify_packid($r->{'source'}->{'package'});
      verify_packid($r->{'target'}->{'package'});
      verify_rev($r->{'source'}->{'rev'}) if exists $r->{'source'}->{'rev'};
    } else {
      die("unknown request action type '$r->{'type'}'\n");
    }
    if ($r->{'type'} eq 'submit' || ($r->{'type'} eq 'delete' && exists($r->{'target'}->{'package'}))) {
      die("request contains multiple source changes for package \"$r->{'target'}->{'package'}\"\n") if $pkgchange{"$r->{'target'}->{'project'}/$r->{'target'}->{'package'}"};
      $pkgchange{"$r->{'target'}->{'project'}/$r->{'target'}->{'package'}"} = 1;
    }
  }
}

sub verify_nevraquery {
  my ($q) = @_;
  verify_arch($q->{'arch'});
  die("binary has no name\n") unless defined $q->{'name'};
  die("binary has no version\n") unless defined $q->{'version'};
  my $f = "$q->{'name'}-$q->{'version'}";
  $f .= "-$q->{'release'}" if defined $q->{'release'};
  verify_filename($f);
  verify_simple($f);
}

sub verify_attribute {
  my $attribute = $_;
  die("no namespace defined\n") unless $attribute->{'namespace'};
  die("no name defined\n") unless $attribute->{'name'};
  verify_simple($attribute->{'namespace'});
  verify_simple($attribute->{'name'});
  verify_simple($attribute->{'binary'}) if $attribute->{'binary'};
  for my $value (@{$attribute->{'value'} || []}) {
    verify_simple($value);
  }
}

sub verify_attributes {
  my $attributes = $_;
  for my $attribute (@{$attributes || []}) {
    verify_attribute($attribute);
  }
}

our $verifyers = {
  'project' => \&verify_projid,
  'package' => \&verify_packid,
  'repository' => \&verify_repoid,
  'arch' => \&verify_arch,
  'job' => \&verify_jobid,
  'package_repository' => \&verify_packid_repository,
  'filename' => \&verify_filename,
  'md5' => \&verify_md5,
  'rev' => \&verify_rev,
  'linkrev' => \&verify_linkrev,
  'bool' => \&verify_bool,
  'num' => \&verify_num,
  'intnum' => \&verify_intnum,
  'port' => \&verify_port,
  'prp' => \&verify_prp,
  'prpa' => \&verify_prpa,
  'resultview' => \&verify_resultview,
};

1;

