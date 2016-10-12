package BSBlameTest;

use strict;
use warnings;
use Data::Dumper;
use Digest::MD5 ();
use Test::More;

use BSRPC;
use BSXML;
use BSXPath;
use BSConfig;
use BSUtil;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(blame_is list_like commit branch create del list);

# Some testing infrastructure code...

sub blame_is {
  my ($test_name, $projid, $packid, $filename, %opts) = @_;
  my $code = delete $opts{'code'} || 200;
  die("'expected' option required\n")
    unless exists $opts{'expected'} || $code != 200;
  my $exp = delete $opts{'expected'};
  $exp .= 'NUMLINES: ' . split("\n", $exp) if $exp;
  # by default, we always expand
  $opts{'expand'} = 1 unless exists $opts{'expand'};
  my $blamedata;
  eval {
    $blamedata = blame($projid, $packid, $filename, %opts);
  };
  if ($code && $code != 200) {
    like($@, qr/^$code/, $test_name);
    return;
  }
  my $file = getfile($projid, $packid, $filename, %opts);
  my @lines = split("\n", $file);
  for (my $i = 0; $i < @lines; $i++) {
    my $blamerev = $blamedata->{'revision'}->[$i];
    my $project = $blamerev->{'project'} || '';
    my $package = $blamerev->{'package'} || '';
    my $rev = $blamerev->{'rev'} || '';
    $lines[$i] = "$project/$package/r$rev: $lines[$i]";
  }
  $lines[@lines] = 'NUMLINES: ' . @lines;
  $file = join("\n", @lines);
  is($file, $exp, $test_name);
}

sub list_like {
  my ($test_name, $projid, $packid, %opts) = @_;
  die("'xpath' option required\n") unless exists $opts{'xpath'};
  my $xpath = delete $opts{'xpath'};
  my $dir = list($projid, $packid, hash2query(%opts));
  my $match = BSXPath::match($dir, $xpath);
  ok(@$match, $test_name);
}

## helpers

# add User-Agent header (unless present), because if the BSRPC UA is used,
# the backend might use different codepath (even though this shouldn't harm...)
sub rpc {
  my ($uri, @args) = @_;
  $uri = {'uri' => $uri} unless ref($uri) eq 'HASH';
  push @{$uri->{'headers'}}, "User-Agent: BSBlameTest"
    unless grep { /'^User-Agent:'/si } @{$uri->{'headers'} || []};
  return BSRPC::rpc($uri, @args);
}

# eek: ls is already imported from BSUtil
sub list {
  my ($projid, $packid, @query) = @_;
  my $uri = "$BSConfig::srcserver/source/$projid";
  $uri .= "/$packid" if $packid;
  return rpc($uri, $BSXML::dir, @query);
}

sub getfile {
  my ($projid, $packid, $filename, %opts) = @_;
  return rpc("$BSConfig::srcserver/source/$projid/$packid/$filename", undef,
             hash2query(%opts));
}

sub putdata {
  my ($uri, $dtd, $data, @query) = @_;
  my $param = {
    'uri' => $uri,
    'request' => 'PUT',
    'data' => $data,
    'headers' => [ 'Content-Type: application/octet-stream' ]
  };
  return rpc($param, $dtd, @query);
}

sub putfile {
  my ($projid, $packid, $filename, $data, @query) = @_;
  my $uri = "$BSConfig::srcserver/source/$projid/$packid/$filename";
  return putdata($uri, $BSXML::revision, $data, @query);
  }

sub putproject {
  my ($projid, @query) = @_;
  my $uri = "$BSConfig::srcserver/source/$projid/_meta";
  my $data = BSUtil::toxml({'name' => $projid}, $BSXML::proj);
  return putdata($uri, $BSXML::proj, $data, @query);
}

sub putpackage {
  my ($projid, $packid, @query) = @_;
  my $uri = "$BSConfig::srcserver/source/$projid/$packid/_meta";
  my $data = BSUtil::toxml({'project' => $projid, 'name' => $packid},
                           $BSXML::pack);
  return putdata($uri, $BSXML::pack, $data, @query);
}

# make sure projid or projid/packid exist
# returns true if projid or projid/packid already exists
# XXX: we always delete $packid, (for the current use cases this is
#      the more "reasonable" behavior)
sub create {
  my ($projid, $packid, @query) = @_;
  my $exists;
  # check if projid exists
  eval {
    $exists = list($projid);
  };
  if ($@) {
    die($@) unless $@ =~ /^404/;
    putproject($projid, @query);
  }
  return defined($exists) unless $packid;
  $exists = undef;
  eval {
    $exists = list($projid, $packid);
  };
  if ($@) {
    die($@) unless $@ =~ /^404/;
  }
  del($projid, $packid) if $exists;
  putpackage($projid, $packid, @query);
  return defined($exists);
}

sub del {
  my ($projid, $packid, @query) = @_;
  my $uri = "$BSConfig::srcserver/source/$projid";
  $uri .= "/$packid" if $packid;
  my $param = {
    'uri' => $uri,
    'request' => 'DELETE'
  };
  return rpc($param, undef, @query);
}

sub hash2query {
  my (%opts) = @_;
  return map { "$_=$opts{$_}" } keys %opts;
}

sub commitfilelist {
  my ($projid, $packid, $entries, @query) = @_;
  my $param = {
    'uri' => "$BSConfig::srcserver/source/$projid/$packid",
    'request' => 'POST',
    'data' => BSUtil::toxml({'entry' => $entries}, $BSXML::dir),
    'headers' => [ 'Content-Type: application/octet-stream' ]
  };
  return rpc($param, $BSXML::dir, "cmd=commitfilelist", @query);
}

sub commit {
  my ($projid, $packid, $opts, %files) = @_;
  my $newcontent = delete $opts->{'newcontent'};
  my $orev = $opts->{'orev'} || 'latest';
  my $ofiles;
  $ofiles = list($projid, $packid, "rev=$orev", "expand=1") unless $newcontent;
  my @entries = @{$ofiles->{'entry'} || []};
  @entries = grep {!exists($files{$_->{'name'}})} @entries;
  # only name and md5 attrs, please (the others don't harm, though)
  for my $e (@entries) {
    delete $e->{$_} for grep {$_ ne "name" && $_ ne "md5"} keys %$e;
  }
  delete $files{$_} for grep {!$files{$_}} keys %files;
  for my $f (keys %files) {
    push @entries, {'name' => $f, 'md5' => Digest::MD5::md5_hex($files{$f})};
  }
  my $todo = commitfilelist($projid, $packid, \@entries, hash2query(%$opts));
  if ($todo->{'error'}) {
    die("unexpected error: $todo->{'error'}\n") unless $todo->{'error'} eq 'missing';
    for (@{$todo->{'entry'} || []}) {
      die("origin files missing: $_->{'name'}\n") unless $files{$_->{'name'}};  # should never happen...
      putfile($projid, $packid, $_->{'name'}, $files{$_->{'name'}}, "rev=repository");
    }
    $todo = commitfilelist($projid, $packid, \@entries, hash2query(%$opts));
    die("cannot commit files: $todo->{'error'}\n") if $todo->{'error'};
  }
  return $todo;
}

sub branch {
  my ($projid, $packid, $oprojid, $opackid, %query) = @_;
  $query{'cmd'} = 'branch';
  $query{'oproject'} = $oprojid;
  $query{'opackage'} = $opackid;
  my $param = {
    'uri' => "$BSConfig::srcserver/source/$projid/$packid",
    'request' => 'POST'
  };
  return rpc($param, $BSXML::revision_acceptinfo, hash2query(%query));
}

sub blame {
  my ($projid, $packid, $filename, %query) = @_;
  $query{'cmd'} = 'blame';
  my $param = {
    'uri' => "$BSConfig::srcserver/source/$projid/$packid/$filename",
    'request' => 'POST'
  };
  return rpc($param, $BSXML::blamedata, hash2query(%query));
}

1;
