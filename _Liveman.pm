package Liveman;
use 5.008001;
use strict;
use warnings;
use utf8;

our $VERSION = "0.01";

use Term::ANSIColor qw/colored/;
use File::Slurper qw/read_text write_text/;
use Markdown::To::POD qw/markdown_to_pod/;


# Конструктор
sub new {
    my $cls = shift;
    my $self = bless {@_}, $cls;
    delete $self->{files} if $self->{files} && !@{$self->{files}};
    $self
}

# Получить путь к тестовому файлу из пути к md-файлу
sub test_path {
    my ($self, $md) = @_;
    $md =~ s!^lib/(.*)\.md$!"t/" . join("/", map {lcfirst($_) =~ s/[A-Z]/"-" . lc $&/gre} split /\//, $1) . ".t" !e;
    $md
}

# Трансформирует md-файлыread_text
sub transforms {
    my ($self) = @_;
    my $mds = $self->{files} // [split /\n/, `find lib -name '*.md'`];

    $self->{count} = 0;

    for my $md (@$mds) {
        my $test = $self->test_path($md);
        my $mdmtime = (stat $md)[9];
        die "Нет файла $md" if !$mdmtime;
        $self->transform($md, $test) if !-e $test || -e $test && $mdmtime > (stat $test)[9];
    }
    $self
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
    my $expected = $x{expected};
    my $q = _q_esc($line =~ s!\s*$!!r);
    my $code = _trim($x{code});

    if(exists $x{is_deeply}) { "is_deeply scalar do {$code}, scalar do {$expected}, '$q';\n" }
    elsif(exists $x{is})   { "is scalar do {$code}, scalar do{$expected}, '$q';\n" }
    elsif(exists $x{qqis}) { my $ex = _qq_esc($expected); "is scalar do {$code}, \"$ex\", '$q';\n" }
    elsif(exists $x{qis})  { my $ex = _q_esc($expected);  "is scalar do {$code}, '$ex', '$q';\n" }
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

    my $inset = "```";
    my @text = split /^(${inset}\w*[ \t])$/mo, $markdown;

    for(my $i=0; $i<@text; $i+=4) {
        my ($mark, $sec1, $code, $sec2) = @text[$i..$i+4];

        push @pod, markdown_to_pod($mark);
        push @test, $mark =~ s/^/# /rmg;

        last unless defined $sec1;
        $i--, $sec2 = $code, $code = "" if $code =~ /^${inset}[ \t]*$/;

        $title = _trim($1) while $mark =~ /^#+[ \t]+(.*)/gm;

        push @pod, $code =~ s/^/\t/gmr;

        my ($infile, $is) = $mark =~ /^(?:File|Файл)[ \t]+(.*?)([\t ]+(?:is|является))?:[\t ]*\n\z/m;
        if($infile && $is) {
            push @test, "{ open my \$__f__, '<:utf8', my \$s = '${\_q_esc($infile)}' or die \"Read \$s: \$!\"; my \$n = join '', <\$__f__>; close \$__f__; is_deeply \$n, '${\_q_esc($code)}', \"File \$s\"; } ";
        }
        elsif($infile) {
            push @test, "{ open my \$__f__, '>:utf8', my \$s = '${\_q_esc($infile)}' or die \"Read \$s: \$!\"; print \$__f__ '${\_q_esc($code)}'; close \$__f__ } ";
        } else {

            if($use_title ne $title) {
                push @test, "done_testing; }; " if $close_subtest;
                $close_subtest = 1;
                push @test, "subtest '${\ _q_esc($title)}' => sub { ";
                $use_title = $title;
            }

            my $test = $code =~ s{^(?<code>.*)#[ \t]*((?<is_deeply>-->|⟶)|(?<is>->|→)|(?<qqis>=>|⇒)|(?<qis>\\>|↦))\s*(?<expected>.+?)[ \t]*$}{ _to_testing($&, %+) }grme;
            push @test, $test;
        }
    }

    push @test, "\n\tdone_testing;\n};\n" if $close_subtest;
    push @test, "\ndone_testing;\n";

    _mkpath($test);
    write_text $test, join "", "use strict; use warnings; use utf8; use open qw/:std :utf8/; use Test::More 0.98; ", @test;

    # Создаём модуль, если его нет
    my $pm = $md =~ s/\.md$/.pm/r;
    if(!-e $pm) {
        my $pkg = ($pm =~ s!^lib/(.*)\.pm$!$1!r) =~ s!/!::!gr;
        write_text $pm, "package $pkg;\n\n1;";
    }

    # Записываем в модуль
    my $pod = join "", @pod; 
    my $module = read_text $pm;
    $module =~ s!(^__END__[\t ]*\n.*)?\z!\n__END__\n\n=encoding utf-8\n\n$pod!smn;
    write_text $pm, $module;

    $self->{count}++;

    print colored("ok", "bright_green"), "\n";

    $self
}

# Запустить тесты
sub tests {
    my ($self) = @_;

    if($self->{files}) {
        local $, = " ";
        $self->{exitcode} = system "yath test -j4 @{$self->{files}}";
        return $self;
    }

    system "cover -delete";
    $self->{exitcode} = system "yath test -j4 --cover" and return $self;
    system "cover -report html_basic";
    system "opera cover_db/coverage.html || xdg-open cover_db/coverage.html" if $self->{open};
    return $self;
}

1;
__END__

=encoding utf-8

=head1 NAME

Liveman - markdown compiller to test and pod.

=head1 SYNOPSIS

    use Liveman;

    my $liveman = Liveman->new;

    # compile lib/Example.md file to t/example.t and added pod to lib/Example.pm
    $liveman->transform("lib/Example.md");

    # compile all lib/**.md files
    $liveman->transforms;

    # start tests with yath
    $liveman->tests;

    # limit liveman to these files for operations transforms and tests (without cover)
    my $liveman = Liveman->new(files => ["lib/Example1.md", "lib/Examples/Example2.md"]);

=head1 DESCRIPTION

The problem with modern projects is that the documentation is disconnected from testing.
This means that the examples in the documentation may not work, and the documentation itself may lag behind the code.

Liveman compile lib/**.md files to t/**.t files
and it added pod-documentation to section __END__ to lib/**.pm files.

Use C<liveman> command for compile the documentation to the tests in catalog of your project and starts the tests:

    liveman
	
=head1 EXAMPLE

Is files:

lib/ray_test_Mod.pm:

	package ray_test_Mod;

	our $A = 10;
	our $B = [1, 2, 3];
	our $C = "\$hi";

	1;

lib/ray_test_Mod.md:
	
	# NAME

	ray_test_Mod — тестовый модуль

	# SYNOPSIS

	```perl
	use ray_test_Mod;

	$ray_test_Mod::A # -> 5+5
	$ray_test_Mod::B # --> [1, 2, 3]

	my $dollar = '$';
	$ray_test_Mod::C # => ${dollar}hi

	$ray_test_Mod::C # \> $hi


	$ray_test_Mod::A # → 5+5
	$ray_test_Mod::B # ⟶ [1, 2, 3]
	$ray_test_Mod::C # ⇒ ${dollar}hi
	$ray_test_Mod::C # ↦ $hi

Start C<liveman>:

	liveman -o
	
This command modify C<pm>-file:

lib/ray_test_Mod.pm:

	package ray_test_Mod;

	our $A = 10;
	our $B = [1, 2, 3];
	our $C = "\$hi";

	1;

	__END__

	=encoding utf-8

	=head1 NAME

	ray_test_Mod — тестовый модуль

	=head1 SYNOPSIS

		use ray_test_Mod;
		
		$ray_test_Mod::A # -> 5+5
		$ray_test_Mod::B # --> [1, 2, 3]
		
		my $dollar = '$';
		$ray_test_Mod::C # => ${dollar}hi
		
		$ray_test_Mod::C # \> $hi
		
		
		$ray_test_Mod::A # → 5+5
		$ray_test_Mod::B # ⟶ [1, 2, 3]
		$ray_test_Mod::C # ⇒ ${dollar}hi
		$ray_test_Mod::C # ↦ $hi

	
And this command make test:

t/ray_test_-mod.t:

	use strict; use warnings; use utf8; use open qw/:std :utf8/; use Test::More 0.98; # # NAME
	# 
	# ray_test_Mod — тестовый модуль
	# 
	# # SYNOPSIS
	# 

	subtest 'SYNOPSIS' => sub { 	use ray_test_Mod;
		
		is scalar do {$ray_test_Mod::A}, scalar do{5+5}, '$ray_test_Mod::A # -> 5+5';
		is_deeply scalar do {$ray_test_Mod::B}, scalar do {[1, 2, 3]}, '$ray_test_Mod::B # --> [1, 2, 3]';
		
		my $dollar = '$';
		is scalar do {$ray_test_Mod::C}, "${dollar}hi", '$ray_test_Mod::C # => ${dollar}hi';
		
		is scalar do {$ray_test_Mod::C}, '$hi', '$ray_test_Mod::C # \> $hi';
		
		
		is scalar do {$ray_test_Mod::A}, scalar do{5+5}, '$ray_test_Mod::A # → 5+5';
		is_deeply scalar do {$ray_test_Mod::B}, scalar do {[1, 2, 3]}, '$ray_test_Mod::B # ⟶ [1, 2, 3]';
		is scalar do {$ray_test_Mod::C}, "${dollar}hi", '$ray_test_Mod::C # ⇒ ${dollar}hi';
		is scalar do {$ray_test_Mod::C}, '$hi', '$ray_test_Mod::C # ↦ $hi';

	# 
	# # DESCRIPTION
	# 
	# It's fine.
	# 
	# # LICENSE
	# 
	# © Yaroslav O. Kosmina
	# 2023

		done_testing;
	};

	done_testing;

Run it with coverage.

Option C<-o> open coverage in browser (coverage file: cover_db/coverage.html).

=head1 LICENSE

⚖ B<GPLv3>

=head1 AUTHOR

Yaroslav O. Kosmina E<lt>darviarush@mail.ruE<gt>

=cut

