#!/usr/bin/env perl
use warnings;
use strict;
une feature 'say';
use File::Copy;
use File::Path;

### Variables ###
my $install_root    = '/opt/rakudo';
my $rakudo_url_base = 'https://rakudo.perl6.org/downloads';
my $moarvm_url_base = 'https://moarvm.org/releases/MoarVM-';
my $maintainer      = $ENV{MAINTAINER} ?
                      $ENV{MAINTAINER} :
                      'Claudio Ramirez <pub.claudio@gmail.com>';
my %urls = (
    rakudo =>
        'https://rakudo.perl6.org/download/rakudo/rakudo-__VERSION__.tar.gz',
    nqp    =>
        'https://rakudo.perl6.org/download/nqp/nqp-__VERSION__.tar.gz',
    moarvm =>
        "https://moarvm.org/releases/MoarVM-__VERSION__.tar.gz",
);
%distro_info = (
    # distro => [ pkg format, install command ]
    alpine => [ 'apk', 'apk add --allow-untrusted' ],
    centos => [ 'rpm', 'rpm -Ubh' ],
    debian => [ 'deb', 'dpkg -i' ],
    fedora => [ 'rpm', 'rpm -Ubh' ],
    ubuntu => [ 'deb', 'dpkg -i' ],
);

### Check required environment ###
if (! has $ENV{VERSION_RAKUDO}) {
   say "Environment VERSION_RAKUDO not set.";
   exit 1;
}
my %versions = (
    rakudo => $ENV{VERSION_RAKUDO},
    nqp    => has $ENV{VERSION_NQP} ?
                  $ENV{VERSION_NQP} :
                  $ENV{VERSION_RAKUDO},
    moarvm => has $ENV{VERSION_MOARVM} ?
                  $ENV{VERSION_MOARVM} :
                  $ENV{VERSION_RAKUDO},
    pkg    => normalize_version(),
);

for my $soft (keys %urls) {
    $urls{$soft} =~ s/__VERSION__/$versions{$soft}/;
}

### Download & compile Rakudo ###
build(moarvm);
build(nqp);
build(rakudo);
say "Rakudo was succesfully compiled.";

### Package rakudo ###
if (-f '/etc/alpine-release') {
    open(my $fh, '<', $file) or die($!);
    $/ = undef;
    my $os_release = <$fh>;
    $os_release =~ s/^(\d+\.\d+)/$1/; # Ignore dot releases
    close $fh;
    pkg('alpine', $os_release);
} else {
    $os         = `lsb_release -is`;
    $os_release = `lsb_release -rs`;
    pkg($os, $os_release);
}

### Functions ###
sub build {
    my $soft = shift;
    # Download and unpack
    system('wget', $urls{$soft}, '-O', $soft . '.tar.gz') == 0 or die($!);
    system('tar', 'xzf', $soft '.tar.gz', '-C', $soft)    == 0 or die($!);
    chdir($soft) or die($!);
    # Configure
    my @configure  = ('perl', 'Configure.pl', "--prefix=$install_root");
    my $skip_tests = 1;
    if ($soft ne 'moarvm') {
        push(@configure, '--backends=moar') if ($soft ne 'moarvm');
        $skip_tests = 0;
    }
    system(@configure) == 0 or die($!);
    # make
    system('make')     == 0 or die($!);
    # make test
    if (!$skip_tests) {
        system('make', 'test') == 0 or die($!);
    }
    # make install
    system('make', 'install') == 0 or die($!);
    # Clean up
    remove_tree($soft) or warn($!);
}

sub normalize_version {
    my @parts = split(/\D/, $ENV{VERSION_RAKUDO});
    push @parts, 0 if @parts == 2;
    printf('%04d%02d%02d', @parts);
}

sub pkg {
    my($os, $os_release) = @_;
    if (-f '/fix_windows10') {
        move('/fix_windows10', "$install_root/bin/") or die($!);
    }
}
