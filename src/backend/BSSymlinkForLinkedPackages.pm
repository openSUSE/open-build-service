#!/usr/bin/perl
package BSSymlinkForLinkedPackages;

use strict; use warnings;

use Exporter qw(import);
use File::Copy qw(copy);

our @EXPORT_OK=qw(
make_symlink_rpms
);

sub is_copy_linked_packages_enabled {
  my ($config_str) = @_;
  if( $config_str && $config_str =~ /CopyLinkedPackages:\s*yes/ ) {
    return 1;
  }

  return 0;
}

sub is_rpmbuildstage_bb_enabled {
  my ($config_str) = @_;
  if( $config_str && $config_str =~ /Rpmbuildstage:\s*bb/ ) {
    return 1;
  }

  return 0;
}

sub symlink_packages {
  my ($src_dir, $dst_dir, $is_rpmbuildstage_bb) = @_;

  my $make_symlink = 0;
  my $file_found = 0;
  if( File::Path::make_path($dst_dir, {mode=>0777}) ) {
    # do nothing if the directory is newly created.
    $make_symlink = 1;
  } else {
    # check if there is any symlinks.
    my @unlink_files;
    opendir( my $DST, $dst_dir );
    while( my $file = readdir $DST ) {
      if( $file =~ /.*.rpm/ || $file eq "rpmlint.log" ) {
        $file_found = 1;
        if( -l "$dst_dir/$file" ) {
          $make_symlink = 1;
          push @unlink_files, "$dst_dir/$file";
        }
      }
    }
    for my $f (@unlink_files) {
      unlink($f);
    }
    # if we do not find any rpm, rpmlint.log, or logfile, we should make symlink!
    if( $file_found == 0 ) {
      $make_symlink = 1;
    }
    closedir($DST);
  }

  # make symlink only if the directory is newly created or any symlink is found.
  if( $make_symlink ) {
    opendir(my $D, $src_dir);
    while( my $file = readdir $D ) {
      if( $file =~ /.src.rpm/ ) {
        if( ! $is_rpmbuildstage_bb ) {
          symlink("$src_dir/$file", "$dst_dir/$file");
        } else {
          print "since <Rpmbuildstage: bb> is declared in project config, do not symlink src.rpm.\n";
        }
      } elsif( $file =~ /.*.rpm/ || $file eq "rpmlint.log" ) {
        symlink("$src_dir/$file", "$dst_dir/$file");
      } elsif( $file eq 'logfile' ) {
        copy("$src_dir/$file", "$dst_dir/$file");
      }
    }
    closedir($D);
  }
}

sub is_package_in_project {
  my ($projpacks, $packid, $linked_p) = @_;
  for my $linked_p_package (keys %{$projpacks->{$linked_p}->{'package'}}) {
    if( $linked_p_package eq $packid ) {
      return 1;
    }
  }
  return 0;
}

sub find_linked_project_for_package {
  my ($projpacks, $linked_projects, $packid) = @_;

  for my $l (@$linked_projects) {
    my $linked_p = $l->{'project'};
    if( is_package_in_project($projpacks, $packid, $linked_p) ) {
      return $linked_p;
    }
  }

  print "$packid: No such package in any linked projects.\n";
  return 0;
}

sub make_symlink_rpms {
  my ($projpacks, $reporoot, $projid, $repoid, $myarch, $packid) = @_;
  # check if it has a linked project.
  if( ! $projpacks->{$projid}->{'link'} ) {
    print "NO link project.\n";
    return ;
  }

  if( ! is_copy_linked_packages_enabled($projpacks->{$projid}->{'config'}) ) {
    print "NOT copying packages from the linked project.\n";
    return ;
  }

  my $is_rpmbuildstage_bb = is_rpmbuildstage_bb_enabled($projpacks->{$projid}->{'config'});

  my $linked_projid = find_linked_project_for_package($projpacks, $projpacks->{$projid}->{'link'}, $packid);
  if( $linked_projid ) {
    print "linked project: $linked_projid\n";

    my $src_dir = "$reporoot/$linked_projid/$repoid/$myarch/$packid";
    my $dst_dir = "$reporoot/$projid/$repoid/$myarch/$packid";
    symlink_packages($src_dir, $dst_dir, $is_rpmbuildstage_bb);
  }
}

1;
