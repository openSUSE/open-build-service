#!/usr/bin/perl -w

package Dfs;

use strict;

our $warnings = 0;

sub new {
    my $class = shift;
    my $self = {
	nodes => {},

	# config
	do_topsort => 0,

	# nodename -> parent nodename
	parent => {},
	backwardedges => {},
	# nodename -> value where value means >0 visited nodes, <0 neighbour nodes, =0 others
	where => {},
	number => undef,

	cyclefree => undef,  # die if graph contains cycles

	visited => {},
	begintime => {},
	endtime => {},
	'time' => undef,
	topsorted => [],
	reversedgraph => {},
	# how many edges end here
	reverseorder => {},

	cycles => {},
	cyclepkgs => {},
	numcycles => 0,
    };
    $self->{'nodes'}=shift;
    bless ($self, $class);
    return $self;
}

# non recursive dfs

sub dfsvisit
{
    my $self = shift;
    my $k = shift;
    my @nodestack;
    my @adl;
    push @nodestack,$k;
    $self->{'where'}->{$k}=-1;
    do
    {
	$k = pop @nodestack;
#	print STDERR "inspect $k, ";
	$self->{'where'}->{$k}=$self->{'number'};
	if(exists $self->{'nodes'}->{$k})
	    { @adl = @{$self->{'nodes'}->{$k}}; }
	else
	    { @adl = (); }
#	for my $a (@adl) {print STDERR "$a "} print STDERR "\n";
	for my $p (@adl)
	{
#	    print STDERR "$p is ", $self->{'where'}->{$p},"\n";
	    if($self->{'where'}->{$p}==0)
	    {
		push @nodestack, $p;
		$self->{'where'}->{$p}=-1;
		$self->{'parent'}->{$p}=$k;
	    }
	    elsif ($self->{'where'}->{$p}>0)
	    {
		if ($self->{'parent'}->{$self->{'parent'}->{$p}} eq $k) {
		    $self->{'parent'}->{$p}=$k;
		}
	    }
	}
    } until($#nodestack==-1);
}

sub startdfs
{
    my $self = shift;
    my $what = shift;
    my @tovisit;
    $self->{'where'} = {};
    $self->{'number'}=1;
    for my $node (keys %{$self->{'nodes'}})
    {
	$self->{'where'}->{$node}=0;
    }

    if(!$what || $what eq '')
    {
	@tovisit=keys %{$self->{'nodes'}};
    }
    else
    {
	@tovisit=@_
    }
    for my $node (@tovisit)
    {
	if(!exists $self->{'nodes'}->{$node})
	{
	    print STDERR "package $node not available\n";
	    next;
	}
	if($self->{'where'}->{$node} == 0)
	{
	    $self->dfsvisit($node);
	    $self->{'number'}++;
	}
    }
}

# recursive dfs

sub parents {
    my ($self, $from, $to) = @_;
    my $pp = $from;
    my @l = ($pp);
    while ($pp = $self->{'parent'}->{$pp}) {
	push @l, $pp;
	last if $to && $pp eq $to;
    }
    return @l;
}

sub addcycle($$)
{
    my $self = shift;
    my $pkgs = shift;
    my $cycles = $self->{'cycles'};
    my $cyclepkgs = $self->{'cyclepkgs'};
    my $cid; # cycle id
    for my $p (@$pkgs) {
	if (defined $cyclepkgs->{$p}) {
	    my $id = $cyclepkgs->{$p};
	    if ($cid && $cid != $id) {
		warn "$p: folding cycle cycle $id (",join(',', @{$cycles->{$id}}),") into $cid (",join(',', @{$cycles->{$cid}}),")\n" if $warnings;
		push @$pkgs, @{$cycles->{$id}};
		for (@{$cycles->{$id}}) {
		    $cyclepkgs->{$_} = $cid;
		}
		delete $cycles->{$id};
	    } else {
		$cid = $id;
	    }
	}
    }
    $cid = $self->{'numcycles'}++ unless defined $cid;
    for (@$pkgs) {
	die "$_ $cyclepkgs->{$_} $cid\n" if exists $cyclepkgs->{$_} && $cyclepkgs->{$_} != $cid; # can't happen
	$cyclepkgs->{$_} = $cid;
    }

    push @{$cycles->{$cid}}, @$pkgs;
}
sub rdfsvisit
{
    my ($self, $k) = @_;
    #printf STDERR "visiting %s %d\n", $k, $self->{'time'};
    $self->{'begintime'}->{$k}=$self->{'time'};
    $self->{'time'}++;
    $self->{'visited'}->{$k}=1;
    # add normal deps if not alread added by prereq
    $self->{'reverseorder'}->{$k}=0 if !exists $self->{'reverseorder'}->{$k};
    for my $p (@{$self->{'nodes'}->{$k}})
    {
	warn "$k requires itself\n" if $warnings && ($p eq $k);

	# unknown dep, should not happen here
	next unless exists $self->{'visited'}->{$p};

	if($self->{'visited'}->{$p}==0)
	{
	    $self->{'parent'}->{$p}=$k;
	    push @{$self->{'reversedgraph'}->{$p}}, $k;
	    $self->{'reverseorder'}->{$k}++;
	    $self->rdfsvisit($p);
	}
	elsif(!exists $self->{'endtime'}->{$p})
	{
	    my @l = $self->parents($k, $p);
	    #warn "dependency loop: $k -> $p\n";
	    $self->addcycle(\@l);
	    warn "dependency loop: ",join(',', @l),"\n" if $warnings || $self->{'cyclefree'};
	    die if $self->{'cyclefree'};
	    push @{$self->{'backwardedges'}->{$k}}, $p;
	}
	else
	{
	    push @{$self->{'reversedgraph'}->{$p}}, $k;
	    $self->{'reverseorder'}->{$k}++;
	    if ($self->{'backwardedges'}->{$p}) {
		#printf STDERR "%s: checking %s edges to %s [%s]\n", $k, $p, join(',', @{$self->{'backwardedges'}->{$p}}), join(',', $self->parents($k));
		my $pp = $k;
		my @l = ($pp);
		while ($pp = $self->{'parent'}->{$pp}) {
		    push @l, $pp;
		    if (grep { $_ eq $pp} @{$self->{'backwardedges'}->{$p}}) {
			$self->addcycle(\@l);
			warn "cross edge is part of a loop: $k -> $p\n" if $warnings;
		    }
		}
	    }
	}
    }
    $self->{'endtime'}->{$k}=$self->{'time'};
    #printf STDERR "done %s %d\n", $k, $self->{'time'};
    push (@{$self->{'topsorted'}}, $k) if $self->{'do_topsort'};
    $self->{'time'}++;
}

sub _unify {
    my %h = map {$_ => 1} @_;
    return grep(delete($h{$_}), @_);
}

sub startrdfs
{
    my $self = shift;
    my $what = $_[0];
    my @tovisit;
    for (qw/visited begintime endtime reversedgraph reverseorder cycles cyclepkgs/) {
	$self->{$_} = {};
    }
    $self->{'time'}=0;
    $self->{'numcycles'}=0;
    $self->{'topsorted'}=[];
    for my $node (keys %{$self->{'nodes'}})
    {
	$self->{'visited'}->{$node}=0;
    }
    $self->{'number'}=1;
    if(!$what || $what eq "ALL" || $what eq "")
    {
	@tovisit=keys %{$self->{'nodes'}};
    }
    else
    {
	@tovisit=@_
    }
    
    for my $node (@tovisit)
    {
	if(!exists $self->{'nodes'}->{$node})
	{
	    print STDERR "package $node not available\n";
	    next;
	}
	if (!exists $self->{'visited'}->{$node}) {
	    print STDERR "$node not known, that should not happen\n";
	} elsif($self->{'visited'}->{$node} == 0) {
	    $self->rdfsvisit($node);
	    $self->{'number'}++;
	}
    }
    my $cycles = $self->{'cycles'};
    for (keys %$cycles) {
	$cycles->{$_} = [ _unify(@{$cycles->{$_}}) ];
    }
}

sub findcycles
{
    my $self = shift;
    return %{$self->{'cycles'}};
}


1;
