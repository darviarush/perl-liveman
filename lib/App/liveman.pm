package App::liveman;
use 5.22.0;
use common::sense;

our $VERSION = "3.2";

use Getopt::Long qw(:config no_ignore_case bundling);
use Pod::Usage;
use Term::ANSIColor qw/:constants/;

use Liveman;

$| = 1;

my $parse_options_ok = GetOptions(
    'help|h'      => \( my $help = 0 ),
    'version|v'   => \( my $version = 0 ),
    'man'         => \( my $man  = 0 ),
    'O|options=s' => \( my $options ),
    'p|prove!'    => \( my $prove = 0 ),
    'o|open!'     => \( my $open = 0 ),
    'c|compile!'  => \( my $compile_only = 0 ),
    'f|force!'    => \( my $compile_force = 0 ),
    'a|append!'   => \( my $append = 0 ),
    'A|new!'      => \( my $project = 0 ),
);

if ( !$parse_options_ok ) {
    pod2usage(2);
}
elsif ($help) {
    pod2usage(
        -input    => $INC{__PACKAGE__ =~ s/::/\//gr . ".pm"},
        -sections => "NAME|SYNOPSIS|DESCRIPTION|OPTIONS",
        -verbose  => 99
    );
}
elsif ($version) {
    print Liveman->VERSION, "\n";
}
elsif ($man) {
    pod2usage(
        -input   => $INC{__PACKAGE__ =~ s/::/\//gr . ".pm"},
        -exitval => 0,
        -verbose => 2,
    );
} elsif($project) {
    require Liveman::Project;
    Liveman::Project->new(pkg => $ARGV[0], license => $ARGV[1])->make;
    exit 0;
}
elsif($append) {
    require Liveman::Append;
    my $liveman = Liveman::Append->new(files => \@ARGV)->appends;
    exit $liveman->{count} > 0? 0: 1;
}
else {
    my $liveman = Liveman->new(
        files => \@ARGV,
        options => $options,
        prove => $prove,
        open => $open,
        compile_force => $compile_force,
    );
    $liveman->transforms;
    exit 0 if $compile_only;
    exit $liveman->tests->{exit_code};
}

1;

__END__

=encoding utf-8

=head1 NAME

Liveman - “Living Guide”. Utility for converting files I<* Lib/**. Md *> in test files (I<< * t/**. T B<) and documentation (> pod B<), which is placed in the corresponding module (> Lib/*. PM * >>)

=head1 SYNOPSIS

	liveman [-h] [--man] [-A pkg [license]] [-w] [-o][-c][-f][-s][-a] [<files> ...]

=head1 DESCRIPTION

The problem of modern projects is that the documentation is separated from testing.
This means that the examples in the documentation may not work, and the documentation itself can lag behind the code.

The method of simultaneous documentation and testing solves this problem.

For the documentation, the I<* MD I<< > format was selected, since it is the most simple for input and widespread.
The areas of code I< >> perl I<< > described in it are broadcast into a test. The documentation is translated into I< >> pod I<< > and is added to the I< >> \ I<_ end _> *> section of the perl module.

In other words, I<* Liveman I<< > converts I<< * Lib/**. MD B<-files to test files (> t/**. T * >>) and documentation that is placed in the corresponding I< >> Lib/**. PM *> module. And immediately launches the tests with coating.

The coating can be viewed in the *Cover_DB/Coverage.html *file.

Note: it is better to immediately place *coctor_db/ *in *.gitignore *.

=head1 OPTIONS

B<-h>, B<--help>

Show a certificate and get out.

B<-v>, B<--version>

Show the version and go out.

	`liveman -v` # ~> ^\d+\.\d+$

B<--man>

Print instructions and end.

B<-c>, B<--compile>

Only compile (without starting the tests).

B<-f>, B<--force>

Convert the*Lib/**. MD*files, even if they have not changed.

B<-p>, B<--prove>

Use the C<Prove> utility for tests, notC<yath>.

B<-o>, B<--open>

Open the coating in the browser.

B<-O>, B<--options> OPTIONS

Transfer the line with the options C<yath> orC<Prove>. These parameters will be added to the default parameters.

Default parameters for C<yath>:

 C<yath test -j4 --cover>

Default parameters for C<Prove>:

 C<prove -Ilib -r t>

I<I<< -A I<< >, * >>-Append * >>

Add functions in C<*.md> fromC<*.pm> and end.

B<-A>, B<--new> PACKAGE [LICENSE]

Create a new repository.

=over

=item * =over

=item * Package * - this is the name of the new package, for example, C<Aion :: view>.

=back

=item * =over

=item * License * is a license name, for example, GPLV3 or Perl_5.

=back

=back

=head1 INSTALL

To install this module in your system, follow the following [command] (https://metacpan.org/pod/app:::

	sudo cpm install -gvv Liveman

=head1 AUTHOR

Yaroslav O. Kosmina L<mailto:dart@cpan.org>

=head1 LICENSE

⚖ I<* gplv3 *>

=head1 COPYRIGHT

The App :: Liveman Module Is Copyright © 2024 Yaroslav O. Kosmina. Rusland. All Rights Reserved.
