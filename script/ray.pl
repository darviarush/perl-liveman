#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use open qw/:std :utf8/;

use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use Term::ANSIColor qw/:constants/;

use Aion::Ray;

my $parse_options_ok = GetOptions(
    'help|h' => \( my $help = 0 ),
    'man'    => \( my $man  = 0 ),

    'e|ext=s'          => \( my $ext          = 'pm,pl,plx,t' ),
    'i|interpreters=s' => \( my $interpreters = 'perl,perl5' ),
);

if ( !$parse_options_ok ) {
    pod2usage(2);
}
elsif ($help) {
    pod2usage(
        -sections => "NAME|SYNOPSIS|DESCRIPTION|OPTIONS|SUBCOMMANDS",
        -verbose  => 99
    );
}
elsif ($man) {
    pod2usage( -exitval => 0, -verbose => 2 );
}
else {
    my @files = @ARGV? @ARGV: split /\n/, `find lib -name '*.md'`;
    
    for my $file (@files) {

        print $file, "\n";
        Aion::Ray->new(file => $file)->transform->test;
    }
}

__END__

=encoding utf-8

=head1 NAME

B<ray> - утилита для преобразования lib/**.md-файлов в файлы тестов (t/**.t) и документацию (POD), которая помещается в соответствующий модуль lib/**.pm

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

    ray [-h] [--man] [<files> ...]

=head1 DESCRIPTION

Преобразует lib/**.md-файлы в файлы тестов (t/**.t) и документацию, которая помещается в соответствующий модуль lib/**.pm
	

=head1 LICENSE

⚖ B<GPLv3>

=head1 AUTHOR

Yaroslav O. Kosmina E<lt>darviarush@mail.ruE<gt>

=cut
