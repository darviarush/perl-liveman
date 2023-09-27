package Liveman;
use 5.22.0;
use common::sense;

our $VERSION = "0.8";

use Term::ANSIColor qw/colored/;
use File::Slurper qw/read_text write_text/;
use Markdown::To::POD qw/markdown_to_pod/;


# Конструктор
sub new {
    my $cls = shift;
    my $self = bless {@_}, $cls;
    delete $self->{files} if $self->{files} && !scalar @{$self->{files}};
    $self
}

# Пакет из пути
sub _pkg($) {
    ( shift =~ s!^lib/(.*)\.\w+$!$1!r ) =~ s!/!::!gr
}

# Переменная из пакета
sub _var($) {
    '$' . lcfirst( shift =~ s!::(\w)?!_${\lc $1}!gr )
}

# Для метода для вставки
sub _md_method(@) {
    my ($pkg, $sub, $args, $remark) = @_;
    my $sub_args = "$sub ($args)";
    $args = "($args)" if $args;

    $remark = "." unless defined $remark;
    my $var = _var $pkg;
    << "END";
## $sub_args

$remark

```perl
my $var = $pkg->new;
${var}->$sub$args  # -> .3
```

END
}

# Для фичи для вставки
sub _md_feature(@) {
    my ($pkg, $has, $remark) = @_;

    $remark = "." unless defined $remark;
    my $var = _var $pkg;
    << "END";
## $has

$remark

```perl
my $var = $pkg->new;

${var}->$has\t# -> .5
```

END
}


# Добавить разделы функций в *.md из *.pm
sub appends {
    my ($self) = @_;
    my $files = $self->{files} // [split /\n/, `find lib -name '*.pm' -a -type f`];
    $self->append($_) for @$files;
    $self
}

# Добавить разделы функций в *.md из *.pm
sub append {
    my ($self, $pm) = @_;

    my $md = $pm =~ s!(\.\w+)?$!.md!r;

    die "Not file $pm!" if !-f $pm;
    $self->mkmd($md) if !-f $md;

    local $_ = read_text $pm;
    my %sub; my %has;
    while(m! (^\# [\ \t]* (?<remark> .*?) [\ \t]* )? \n (
        sub \s+ (?<sub> (\w+|::)+ ) .* 
            ( \s* my \s* \( \s* (\$self,? \s* )? (?<args>.*?) \s* \) \s* = \s* \@_; )?
        | has \s+ (?<has> (\w+|'\w+'|"\w+"|\[ \s* ([^\[\]]*?) \s* \])+ )
    ) !mgxn) {
        $sub{$+{sub}} = {%+} if exists $+{sub} and "_" ne substr $+{sub}, 0, 1;
        $has{$+{has}} = {%+} if exists $+{has} and "_" ne substr $+{has}, 0, 1;
    }

    return $self if !keys %sub && !keys %has;

    $_ = read_text $md;

    my $pkg = _pkg $md;

    my $added = 0;

    s{^\#[\ \t]+( (?<is>METHODS|SUBROUTINES) | DESCRIPTION )
        (^```.*?^```|.)*? (?= ^\#\s)
    }{
        my $x = $&; my $is = $+{is};
        if($is) {
            while($x =~ /^\#\#[\ \t]+(\w+)/gm) {
                delete $sub{$1};
            }
        }
        $added += keys %sub;
        join "", $x, $is? (): "# SUBROUTINES/METHODS\n\n", map { _md_method $pkg, $_, $sub{$_}{args}, $sub{$_}{remark} } sort keys %sub;
    }emsx or die "Нет секции DESCRIPTION!" if keys %sub;

    s{^\#[\ \t]+((?<is>FEATURES) | DESCRIPTION) 
        (^```.*?^```|.)*? (?= ^\#\s)
    }{
        my $x = $&; my $is = $+{is};
        if($is) {
            while($x =~ /^\#\#[\ \t]+([^\n]+?)[\ \t]*/gm) {
                delete $has{$1};
            }
        }
        $added += keys %has;
        join "", $x, $is? (): "# FEATURES\n\n", map { _md_feature $pkg, $_, $sub{$_}{remark} } sort keys %has;
    }emsx or die "Нет секции DESCRIPTION!" if keys %has;


    if ($added) {
        write_text $md, $_;
        print "🔖 $pm ", colored("⊂", "BRIGHT_GREEN"), " $md ", "\n",
            "  ", scalar keys %has? (colored("FEATURES ", "BRIGHT_WHITE"), join(colored(", ", "red"), sort keys %has), "\n"): (),
            "  ", scalar keys %sub? (colored("SUBROUTINES ", "BRIGHT_WHITE"), join(colored(", ", "red"), sort keys %sub), "\n"): (),
        ;
    } else {
        print "🔖 $pm\n";
    }

    $self->{count}++;
    $self->{added} = $added;
    $self
}

sub _git_user_name { shift->{_git_user_name} //= _trim(`git config user.name`) }
sub _git_user_email { shift->{_git_user_email} //= _trim(`git config user.email`) }
sub _year { shift->{_year} //= _trim(`date +%Y`) }
sub _license { shift->{_license} //= -r "minil.toml" && read_text("minil.toml") =~ /^\s*license\s*=\s*"([^"\n]*)"/m ? ($1 eq "perl_5"? "Perl5": uc($1) =~ s/_/v/r): "Perl5" }
sub _land { shift->{_land} //= `curl "https://ipapi.co/\$(curl https://2ip.ru --connect-timeout 3 --max-time 3 -Ss)/json/" --connect-timeout 3 --max-time 3 -Ss` =~ /country_name": "([^"\n]*)"/ ? ($1 eq "Russia" ? "Rusland" : $1) : 'Rusland' }

# Добавить разделы функций в *.md из *.pm
sub mkmd {
    my ($self, $md) = @_;

    my $pkg = _pkg $md;

    my $author = $self->_git_user_name;
    my $email = $self->_git_user_email;
    my $year = $self->_year;
    my $license = $self->_license;
    my $land = $self->_land;

    write_text $md, << "END";
# NAME

$pkg - 

# SYNOPSIS

```perl
use $pkg;

my ${\_var $pkg} = $pkg->new;
```

# DESCRIPION

.

# SUBROUTINES

# INSTALL

For install this module in your system run next [command](https://metacpan.org/pod/App::cpm):

```sh
sudo cpm install -gvv $pkg
```

# AUTHOR

$author [$email](mailto:$email)

# LICENSE

⚖ **$license**

# COPYRIGHT

The $pkg module is copyright © $year $author. $land. All rights reserved.
END
}

# Получить путь к тестовому файлу из пути к md-файлу
sub test_path {
    my ($self, $md) = @_;
    $md =~ s!^lib/(.*)\.md$!
        join "", "t/", join("/", map {
            lcfirst($_) =~ s/[A-Z]/"-" . lc $&/gre
        } split /\//, $1), ".t"
    !e;
    $md
}

# Трансформирует md-файлы
sub transforms {
    my ($self) = @_;
    my $mds = $self->{files} // [split /\n/, `find lib -name '*.md'`];

    $self->{count} = 0;

    if($self->{compile_force}) {
        $self->transform($_) for @$mds;
    } else {
        for my $md (@$mds) {
            my $test = $self->test_path($md);
            my $mdmtime = (stat $md)[9];
            die "Нет файла $md" if !$mdmtime;
            $self->transform($md, $test) if !-e $test || -e $test && $mdmtime > (stat $test)[9];
        }
    }

    if(-f "minil.toml" && -r "minil.toml") {
        my $is_copy; my $name;
        eval {
            my $minil = read_text("minil.toml");
            ($name) = $minil =~ /^name = "([\w:-]+)"/m;
            $name =~ s!(-|::)!/!g;
            $name = "lib/$name.md";
            if(-f $name && -r $name) {
                if(!-e "README.md" || -e "README.md"
                    && (stat $name)[9] > (stat "README.md")[9]) {
                    write_text "README.md", read_text $name;
                    $is_copy = 1;
                }
            }
        };
        if($@) {warn $@}
        elsif($is_copy) {
            print "📘 $name ", colored("↦", "white"), " README.md ", colored("...", "white"), " ", colored("ok", "bright_green"), "\n";
        }
    }

    $self
}

# Эскейпинг для qr!!
sub _qr_esc {
    $_[0] =~ s/!/\\!/gr
}

# Эскейпинг для строки в двойных кавычках
sub _qq_esc {
    $_[0] =~ s!"!\\"!gr
}

# Эскейпинг для строки в одинарных кавычках
sub _q_esc {
    $_[0] =~ s!'!\\'!gr
}

# Обрезает пробельные символы
sub _trim {
    $_[0] =~ s!^\s*(.*?)\s*\z!$1!sr
}

# Создаёт путь
sub _mkpath {
    my ($p) = @_;
    mkdir $`, 0755 while $p =~ /\//g;
}

# Строка кода для тестирования
sub _to_testing {
    my ($line, %x) = @_;

    return $x{code} if $x{code} =~ /^\s*#/;

    my $expected = $x{expected};
    my $q = _q_esc($line =~ s!\s*$!!r);
    my $code = _trim($x{code});

    if(exists $x{is_deeply}) { "::is_deeply scalar do {$code}, scalar do {$expected}, '$q';\n" }
    elsif(exists $x{is})   { "::is scalar do {$code}, scalar do{$expected}, '$q';\n" }
    elsif(exists $x{qqis}) { my $ex = _qq_esc($expected); "::is scalar do {$code}, \"$ex\", '$q';\n" }
    elsif(exists $x{qis})  { my $ex = _q_esc($expected);  "::is scalar do {$code}, '$ex', '$q';\n" }
    elsif(exists $x{like})  { my $ex = _qr_esc($expected);  "::like scalar do {$code}, qr!$ex!, '$q';\n" }
    elsif(exists $x{unlike})  { my $ex = _qr_esc($expected);  "::unlike scalar do {$code}, qr!$ex!, '$q';\n" }
    else { # Что-то ужасное вырвалось на волю!
        "???"
    }
}

# Трансформирует md-файл в тест и документацию
sub transform {
    my ($self, $md, $test) = @_;
    $test //= $self->test_path($md);

    print "🔖 $md ", colored("↦", "white"), " $test ", colored("...", "white"), " ";

    my $markdown = read_text($md);

    my @pod; my @test; my $title = 'Start'; my $close_subtest; my $use_title = 1;

    my @text = split /^(```\w*[ \t]*(?:\n|\z))/mo, $markdown;

    for(my $i=0; $i<@text; $i+=4) {
        my ($mark, $sec1, $code, $sec2) = @text[$i..$i+4];

        push @pod, markdown_to_pod($mark);
        push @test, $mark =~ s/^/# /rmg;

        last unless defined $sec1;
        $i--, $sec2 = $code, $code = "" if $code =~ /^```[ \t]*$/;

        die "=== mark ===\n$mark\n=== sec1 ===\n$sec1\n=== code ===\n$code\n=== sec2 ===\n$sec2\n\nsec2 ne ```" if $sec2 ne "```\n";

        $title = _trim($1) while $mark =~ /^#+[ \t]+(.*)/gm;

        push @pod, "\n", ($code =~ s/^/\t/gmr), "\n";

        my ($infile, $is) = $mark =~ /^(?:File|Файл)[ \t]+(.*?)([\t ]+(?:is|является))?:[\t ]*\n\z/m;
        if($infile) {
            my $real_code = $code =~ s/^\\(```\w*[\t ]*$)/$1/mgro;
            if($is) { # тестируем, что текст совпадает
                push @test, "\n{ my \$s = '${\_q_esc($infile)}'; open my \$__f__, '<:utf8', \$s or die \"Read \$s: \$!\"; my \$n = join '', <\$__f__>; close \$__f__; ::is \$n, '${\_q_esc($real_code)}', \"File \$s\"; }\n";
            }
            else { # записываем тект в файл
                #push @test, "\n{ my \$s = main::_mkpath_('${\_q_esc($infile)}'); open my \$__f__, '>:utf8', \$s or die \"Read \$s: \$!\"; print \$__f__ '${\_q_esc($real_code)}'; close \$__f__ }\n";
                push @test, "#\@> $infile\n", $real_code =~ s/^/#>> /rgm, "#\@< EOF\n";
            }
        } elsif($sec1 =~ /^```(?:perl)?[ \t]*$/) {

            if($use_title ne $title) {
                push @test, "done_testing; }; " if $close_subtest;
                $close_subtest = 1;
                push @test, "subtest '${\ _q_esc($title)}' => sub { ";
                $use_title = $title;
            }

            my $test = $code =~ s{^(?<code>.*)#[ \t]*((?<is_deeply>-->|⟶)|(?<is>->|→)|(?<qqis>=>|⇒)|(?<qis>\\>|↦)|(?<like>~>|↬)|(?<unlike><~|↫))\s*(?<expected>.+?)[ \t]*\n}{ _to_testing($&, %+) }grme;
            push @test, "\n", $test, "\n";
        }
        else {
            push @test, "\n", $code =~ s/^/# /rmg, "\n";
        }
    }

    push @test, "\n\tdone_testing;\n};\n" if $close_subtest;
    push @test, "\ndone_testing;\n";

    _mkpath($test);
    my $mkpath = q{sub _mkpath_ { my ($p) = @_; length($`) && !-e $`? mkdir($`, 0755) || die "mkdir $`: $!": () while $p =~ m!/!g; $p }};
    my $write_files = q{open my $__f__, "<:utf8", $t or die "Read $t: $!"; read $__f__, $s, -s $__f__; close $__f__; while($s =~ /^#\\@> (.*)\n((#>> .*\n)*)#\\@< EOF\n/gm) { my ($file, $code) = ($1, $2); $code =~ s/^#>> //mg; open my $__f__, ">:utf8", _mkpath_($file) or die "Write $file: $!"; print $__f__ $code; close $__f__; }};
    #my @symbol = ('a'..'z', 'A'..'Z', '0' .. '9', '-', '_');
    # "-" . join("", map $symbol[rand(scalar @symbol)], 1..6)
    my $test_path = join "", "/tmp/.liveman/",
        `pwd` =~ s/^.*?([^\/]+)\n$/$1/rs,
        $test =~ s!^t/(.*)\.t$!/$1!r =~ y/\//!/r, "/";
    my $chdir = "my \$t = `pwd`; chop \$t; \$t .= '/' . __FILE__; my \$s = '${\ _q_esc($test_path)}'; `rm -fr '\$s'` if -e \$s; chdir _mkpath_(\$s) or die \"chdir \$s: \$!\";";
    # use Carp::Always::Color ::Term;
    my $die = 'use Scalar::Util qw//; use Carp qw//; $SIG{__DIE__} = sub { my ($s) = @_; if(ref $s) { $s->{STACKTRACE} = Carp::longmess "?" if "HASH" eq Scalar::Util::reftype $s; die $s } else {die Carp::longmess defined($s)? $s: "undef" }};';
    write_text $test, join "", "use common::sense; use open qw/:std :utf8/; use Test::More 0.98; $mkpath BEGIN { $die $chdir $write_files } ", @test;

    # Создаём модуль, если его нет
    my $pm = $md =~ s/\.md$/.pm/r;
    if(!-e $pm) {
        my $pkg = ($pm =~ s!^lib/(.*)\.pm$!$1!r) =~ s!/!::!gr;
        write_text $pm, "package $pkg;\n\n1;";
    }

    # Трансформируем модуль (pod и версия):
    my $pod = join "", @pod;
    my $module = read_text $pm;
    $module =~ s!(\s*\n__END__[\t ]*\n.*)?$!\n\n__END__\n\n=encoding utf-8\n\n$pod!sn;

    # Меняем версию:
    my $v = uc "version";
    my ($version) = $markdown =~ /^#[ \t]+$v\s+([\w\.-]{1,32})\s/m;
    $module =~ s!^(our\s*\$$v\s*=\s*)["']?[\w.-]{1,32}["']?!$1"$version"!m if defined $version;
    write_text $pm, $module;

    $self->{count}++;

    print colored("ok", "bright_green"), "\n";

    $self
}

# Запустить тесты
sub tests {
    my ($self) = @_;

    my $cover = "/usr/bin/site_perl/cover";
    $cover = 'cover' if !-e $cover;

    my $yath = "/usr/bin/site_perl/yath";
    $yath = 'yath' if !-e $yath;

    my $options = $self->{options};

    if($self->{files}) {
        my @tests = map $self->test_path($_), @{$self->{files}};
        local $, = " ";
        $self->{exit_code} = system $self->{prove}
            ? "prove -Ilib $options @tests"
            : "$yath test -j4 $options @tests";
        return $self;
    }

    my $perl5opt = $ENV{PERL5OPT};

    system "$cover -delete";
    if($self->{prove}) {
        local $ENV{PERL5OPT} = "$perl5opt -MDevel::Cover";
        $self->{exit_code} = system "env | grep PERL5OPT; prove -Ilib -r t $options";
        #$self->{exit_code} = system "prove --exec 'echo `pwd`/lib && perl -MDevel::Cover -I`pwd`/lib' -r t";
    } else {
        $self->{exit_code} = system "$yath test -j4 --cover $options";
    }
    return $self if $self->{exit_code};
    system "$cover -report html_basic";
    system "(opera cover_db/coverage.html || xdg-open cover_db/coverage.html) &> /dev/null" if $self->{open};
    return $self;
}

1;

__END__

=encoding utf-8

=head1 NAME

Liveman - markdown compiller to test and pod.

=head1 VERSION

0.7

=head1 SYNOPSIS

File lib/Example.md:

	Twice two:
	\```perl
	2*2  # -> 2+2
	\```

Test:

	use Liveman;
	
	my $liveman = Liveman->new(prove => 1);
	
	# compile lib/Example.md file to t/example.t and added pod to lib/Example.pm
	$liveman->transform("lib/Example.md");
	
	$liveman->{count}   # => 1
	-f "t/example.t"    # => 1
	-f "lib/Example.pm" # => 1
	
	# compile all lib/**.md files with a modification time longer than their corresponding test files (t/**.t)
	$liveman->transforms;
	$liveman->{count}   # => 0
	
	# compile without check modification time
	Liveman->new(compile_force => 1)->transforms->{count} # => 1
	
	# start tests with yath
	my $yath_return_code = $liveman->tests->{exit_code};
	
	$yath_return_code           # => 0
	-f "cover_db/coverage.html" # => 1
	
	# limit liveman to these files for operations transforms and tests (without cover)
	my $liveman2 = Liveman->new(files => [], force_compile => 1);

=head1 DESCRIPION

The problem with modern projects is that the documentation is disconnected from testing.
This means that the examples in the documentation may not work, and the documentation itself may lag behind the code.

Liveman compile C<lib/**>.md files to C<t/**.t> files
and it added pod-documentation to section C<__END__> to C<lib/**.pm> files.

Use C<liveman> command for compile the documentation to the tests in catalog of your project and starts the tests:

 liveman

Run it with coverage.

Option C<-o> open coverage in browser (coverage file: C<cover_db/coverage.html>).

Liveman replace C<our $VERSION = "...";> in C<lib/**.pm> from C<lib/**.md> if it exists in pm and in md.

If exists file B<minil.toml>, then Liveman read C<name> from it, and copy file with this name and extension C<.md> to README.md.

=head2 TYPES OF TESTS

Section codes C<noname> or C<perl> writes as code to C<t/**.t>-file. And comment with arrow translates on test from module C<Test::More>.

The test name set as the code-line.

=head3 C<is>

Compare two expressions for equivalence:

	"hi!" # -> "hi" . "!"
	"hi!" # → "hi" . "!"

=head3 C<is_deeply>

Compare two expressions for structures:

	"hi!" # --> "hi" . "!"
	"hi!" # ⟶ "hi" . "!"

=head3 C<is> with extrapolate-string

Compare expression with extrapolate-string:

	my $exclamation = "!";
	"hi!2" # => hi${exclamation}2
	"hi!2" # ⇒ hi${exclamation}2

=head3 C<is> with nonextrapolate-string

Compare expression with nonextrapolate-string:

	'hi${exclamation}3' # \> hi${exclamation}3
	'hi${exclamation}3' # ↦ hi${exclamation}3

=head3 C<like>

It check a regular expression included in the expression:

	'abbc' # ~> b+
	'abc'  # ↬ b+

=head3 C<unlike>

It check a regular expression excluded in the expression:

	'ac' # <~ b+
	'ac' # ↫ b+

=head2 EMBEDDING FILES

Each test is executed in a temporary directory, which is erased and created when the test is run.

This directory format is /tmp/.liveman/I<project>/I<path-to-test>/.

Code section in md-file prefixed line B<< File C<path>: >> write to file in rintime testing.

Code section in md-file prefixed line B<< File C<path> is: >> will be compared with the file by the method C<Test::More::is>.

File experiment/test.txt:

	hi!

File experiment/test.txt is:

	hi!

B<Attention!> An empty string between the prefix and the code is not allowed!

Prefixes maybe on russan: C<Файл path:> and C<Файл path является:>.

=head1 METHODS

=head2 new (%param)

Constructor. Has arguments:

=over

=item 1. C<files> (array_ref) — list of md-files for methods C<transforms> and C<tests>.

=item 2. C<open> (boolean) — open coverage in browser. If is B<opera> browser — open in it. Else — open via C<xdg-open>.

=item 3. C<force_compile> (boolean) — do not check the md-files modification time.

=item 4. C<options> — add options in command line to yath or prove.

=item 5. C<prove> — use prove, but use'nt yath.

=back

=head2 test_path ($md_path)

Get the path to the C<t/**.t>-file from the path to the C<lib/**.md>-file:

	Liveman->new->test_path("lib/PathFix/RestFix.md") # => t/path-fix/rest-fix.t

=head2 transform ($md_path, [$test_path])

Compile C<lib/**.md>-file to C<t/**.t>-file.

And method C<transform> replace the B<pod>-documentation in section C<__END__> in C<lib/**.pm>-file. And create C<lib/**.pm>-file if it not exists.

File lib/Example.pm is:

	package Example;
	
	1;
	
	__END__
	
	=encoding utf-8
	
	Twice two:
	
		2*2  # -> 2+2
	

File C<lib/Example.pm> was created from file C<lib/Example.md> described in section C<SINOPSIS> in this document.

=head2 transforms ()

Compile C<lib/**.md>-files to C<t/**.t>-files.

All if C<< $self-E<gt>{files} >> is empty, or C<< $self-E<gt>{files} >>.

=head2 tests ()

Tests C<t/**.t>-files.

All if C<< $self-E<gt>{files} >> is empty, or C<< $self-E<gt>{files} >> only.

=head2 mkmd ($md)

It make md-file.

=head2 appends ()

Append to C<lib/**.md> from C<lib/**.pm> subroutines and features.

=head2 append ($path)

Append subroutines and features from the module with C<$path> into its documentation in the its sections.

File lib/Alt/The/Plan.pm:

	package Alt::The::Plan;
	
	sub planner {
		my ($self) = @_;
	}
	
	# This is first!
	sub miting {
		my ($self, $meet, $man, $woman) = @_;
	}
	
	sub _exquise_me {
		my ($self, $meet, $man, $woman) = @_;
	}
	
	1;



	-e "lib/Alt/The/Plan.md" # -> undef
	
	# Set the mocks:
	*Liveman::_git_user_name = sub {'Yaroslav O. Kosmina'};
	*Liveman::_git_user_email = sub {'dart@cpan.org'};
	*Liveman::_year = sub {2023};
	*Liveman::_license = sub {"Perl5"};
	*Liveman::_land = sub {"Rusland"};
	
	my $liveman = Liveman->new->append("lib/Alt/The/Plan.pm");
	$liveman->{count}	# -> 1
	$liveman->{added}	# -> 2
	
	-e "lib/Alt/The/Plan.md" # -> 1
	
	# And again:
	$liveman = Liveman->new->append("lib/Alt/The/Plan.pm");
	$liveman->{count}	# -> 1
	$liveman->{added}	# -> 0

File lib/Alt/The/Plan.md is:

	# NAME
	
	Alt::The::Plan - 
	
	# SYNOPSIS
	
	\```perl
	use Alt::The::Plan;
	
	my $alt_the_plan = Alt::The::Plan->new;
	\```
	
	# DESCRIPION
	
	.
	
	# SUBROUTINES
	
	## miting ($meet, $man, $woman)
	
	This is first!
	
	\```perl
	my $alt_the_plan = Alt::The::Plan->new;
	$alt_the_plan->miting($meet, $man, $woman)  # -> .3
	\```
	
	## planner ()
	
	.
	
	\```perl
	my $alt_the_plan = Alt::The::Plan->new;
	$alt_the_plan->planner  # -> .3
	\```
	
	# INSTALL
	
	For install this module in your system run next [command](https://metacpan.org/pod/App::cpm):
	
	\```sh
	sudo cpm install -gvv Alt::The::Plan
	\```
	
	# AUTHOR
	
	Yaroslav O. Kosmina [dart@cpan.org](mailto:dart@cpan.org)
	
	# LICENSE
	
	⚖ **Perl5**
	
	# COPYRIGHT
	
	The Alt::The::Plan module is copyright © 2023 Yaroslav O. Kosmina. Rusland. All rights reserved.

=head1 INSTALL

Add to B<cpanfile> in your project:

	on 'test' => sub {
		requires 'Liveman', 
			git => 'https://github.com/darviarush/perl-liveman.git',
			ref => 'master',
		;
	};

And run command:

	$ sudo cpm install -gvv

=head1 AUTHOR

Yaroslav O. Kosmina LL<mailto:dart@cpan.org>

=head1 LICENSE

⚖ B<GPLv3>

=head1 COPYRIGHT

The Alt::The::Plan module is copyright © 2023 Yaroslav O. Kosmina. Rusland. All rights reserved.
