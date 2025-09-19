package Liveman;
use 5.22.0;
use common::sense;

our $VERSION = "3.2";

use Cwd::utf8 qw/getcwd/;
use File::Basename qw/dirname/;
use File::Find::Wanted qw/find_wanted/;
use File::Spec qw//;
use File::Slurper qw/read_text write_text/;
use File::Path qw/mkpath rmtree/;
use Locale::PO qw//;
use Markdown::To::POD qw/markdown_to_pod/;
use Term::ANSIColor qw/colored/;
use Text::Trim qw/trim/;
use Liveman::Cpanfile;

# Конструктор
sub new {
    my $cls = shift;
    my $self = bless {@_}, $cls;
    delete $self->{files} if $self->{files} && !scalar @{$self->{files}};
    $self
}

# Получить путь к тестовому файлу из пути к md-файлу
sub test_path {
    my ($self, $md) = @_;

    my ($volume, $chains) = File::Spec->splitpath($md, 1);
    my @dirs = File::Spec->splitdir($chains);

    shift @dirs; # Удаляем lib
    $dirs[$#dirs] =~ s!\.md$!\.t!;

    my $md = File::Spec->catfile("t", map { lcfirst($_) =~ s/[A-Z]/"-" . lc $&/gre } @dirs);

    $md
}

# Трансформирует md-файлы
sub transforms {
    my ($self) = @_;
    my $mds = $self->{files} // [ find_wanted(sub { /\.md$/ }, "lib") ];

    $self->{count} = 0;

    if($self->{compile_force}) {
        $self->transform($_) for @$mds;
    } else {
        for my $md (@$mds) {
            my $test = $self->test_path($md);
            my $mdmtime = (stat $md)[9];
            die "Not exists file $md!" if !$mdmtime;
            $self->transform($md, $test) if !-e $test
                || $mdmtime > (stat $test)[9];
        }
    }

    # minil.toml и README.md
    if(-f "minil.toml" && -r "minil.toml") {
        my $is_copy; my $name;
        eval {
            my $minil = read_text("minil.toml");
            ($name) = $minil =~ /^name = "([\w:-]+)"/m;
            $name =~ s!(-|::)!/!g;
            $name = "lib/$name.md";
            if(-f $name && -r $name) {
                if(!-e "README.md" || (stat $name)[9] > (stat "README.md")[9]) {
                    my $readme = read_text $name;
                    $readme =~ s/^!\w+:\w+\s+//;
                    write_text "README.md", $readme;
                    $is_copy = 1;
                }
            }
        };
        if($@) {warn colored("minil.toml", 'red') . ": $@"}
        elsif($is_copy) {
            print colored(" ^‥^", "bright_black"), " $name ", colored("-->", "bright_black"), " README.md ", colored("...", "bright_white"), " ", colored("ok", "bright_green"), "\n";
        }
    }

#     # cpanfile
#     if (!$self->{files}) {
#         eval {
#             $self->cpanfile($mds);
#         };
#         warn colored("cpanfile", 'red') . ": $@" if $@;
#     }

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

# Строка кода для тестирования
sub _to_testing {
    my ($line, %x) = @_;

    return $x{code} if $x{code} =~ /^\s*#/;

    my $expected = $x{expected};
    my $q = _q_esc($line =~ s!\s*$!!r);
    my $code = trim($x{code});

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

# Обрезает строки вначале и все пробельные символы в конце
sub _first_line_trim ($) {
	local ($_) = @_;
    s/^([\t ]*\n)*//;
    s/\s*$//;
    $_
}

# Преобразует из строчного формата
sub _from_str ($) {
    local ($_) = @_;
    s/^"(.*)"$/$1/s;
    s/\\(.)/ $1 eq "n"? "\n": $1 eq "t"? "\t": $1 /ge;
    $_
}

# Загрузка po
sub load_po {
	my ($self, $md, $from, $to) = @_;

    @$self{qw/from to/} = ($from, $to);

    return $self unless $md;

    my ($volume, $chains) = File::Spec->splitpath($md, 1);
    my @dirs = File::Spec->splitdir($chains);
    $dirs[0] = 'i18n'; # Удаляем lib
    $dirs[$#dirs] =~ s!\.md$!\.$from-$to.po!;

    $self->{po_file} = File::Spec->catfile(@dirs);
    my $i18n = File::Spec->catfile(@dirs[0..$#dirs-1]);
    mkpath($i18n);

    my $manager = $self->{po_manager} = Locale::PO->new;
    my $po = -e $self->{po_file}? $manager->load_file_ashash($self->{po_file}, "utf8"): {};

    my %po;
    my $lineno = 0;
    for(keys %$po) {
        my $val = $po->{$_};
        $po{_first_line_trim(_from_str($_))} = $val;
    }
    
    $self->{po} = \%po;

	$self
}

# Сохранение po
sub save_po {
	my ($self) = @_;
	
    return $self unless $self->{from};

    my @po = grep $_->{__used}, sort { $a->{loaded_line_number} <=> $b->{loaded_line_number} } values %{$self->{po}};

    $self->{po_manager}->save_file_fromarray($self->{po_file}, \@po, "utf8");

	$self
}

# Функция переводит текст с одного языка на другой используя утилиту trans
sub trans {
	my ($self, $text, $lineno) = @_;

    $text = _first_line_trim($text);

    return $text if $text eq "";
    return $text if $self->{from} eq "ru" && $text =~ /^[\x00-\x7F]*$/a;

    my $po = $self->{po}{$text};
    $po->{__used} = 1, $po->loaded_line_number($lineno), return _from_str($po->msgstr) if defined $po;

    my $dir = File::Spec->catfile(File::Spec->tmpdir, ".liveman");
    mkpath($dir);
    my $trans_from = File::Spec->catfile($dir, $self->{from});
    my $trans_to = File::Spec->catfile($dir, $self->{to});

    write_text($trans_from, $text);

    my @progress = qw/\\ | \/ -/;
    print $progress[$self->{trans_i}++ % @progress], "\033[D";

    my $cmd = "trans -no-auto -b $self->{from}:$self->{to} < $trans_from > $trans_to";
    if(system $cmd) {
        die "$cmd: failed to execute: $!" if $? == -1;
        die printf "%s: child died with signal %d, %s coredump",
            $cmd, ($? & 127), ($? & 128) ? 'with' : 'without'
                if $? & 127;
        die printf "%s: child exited with value %d", $cmd, $? >> 8;
    }

    my $trans = _first_line_trim(read_text($trans_to));

    $po = Locale::PO->new(
        -msgid => $text,
        -msgstr => $trans,
        -loaded_line_number => $lineno,
    );

    $po->{__used} = 1;
    $self->{po}{$text} = $po;

    $trans
}

# Заголовки не переводим
# Так же разбиваем по параграфам
sub trans_paragraph {
	my ($self, $paragraph, $lineno) = @_;

    join "", map {
        /^(#|\s*$)/n ? $_: join "", "\n", $self->trans(_first_line_trim($_), $lineno += 0.001), "\n\n"
    } split /((?:[\t\ ]*\n){2,})/, $paragraph
}

# Переводит markdown в pod
sub markdown2pod {
	my ($self, $markdown) = @_;
    local $_ = markdown_to_pod($markdown);
    s/([\t ])(<[\w:]+>)/$1L$2/g;
    s!L+<https://metacpan.org/pod/([\w:]+)>!L<$1>!ag;
	$_
}

# Трансформирует md-файл в тест и документацию
sub transform {
    my ($self, $md, $test) = @_;
    local $_;
    $test //= $self->test_path($md);

    print colored(" ^‥^", "bright_black"), " $md ", colored("-->", "bright_black"), " $test ", colored("...", "bright_white"), " ";

    my $markdown = read_text($md);

    my $from; my $to;
    $markdown =~ s/^!(\w+):(\w+)[\t ]*\n/$from = $1; $to = $2; "\n"/e;
    $self->load_po($md, $from, $to);

    my @pod; my @test; my $title = 'Start'; my $close_subtest; my $use_title = 1;

    my @text = split /^(```\w*[ \t]*(?:\n|\z))/mo, $markdown;

    for(my $i=0; $i<@text; $i+=4) {
        $text[$i] =~ s!([ \t])<(\w+(?:::\w+)*)>!${1}[$2](https://metacpan.org/pod/$2)!g;

        # mark - текст, sec1 - ```perl, code - код, sec2 - ```
        my ($mark, $sec1, $code, $sec2) = @text[$i..$i+4];

        push @pod, $self->markdown2pod($from? $self->trans_paragraph($mark, $i): $mark);
        push @test, $mark =~ s/^/# /rmg;

        last unless defined $sec1;
        $i--, $sec2 = $code, $code = "" if $code =~ /^```[ \t]*$/;

        die "=== mark ===\n$mark\n=== sec1 ===\n$sec1\n=== code ===\n$code\n=== sec2 ===\n$sec2\n\nsec2 ne ```" if $sec2 ne "```\n";

        $title = trim($1) while $mark =~ /^#+[ \t]+(.*)/gm;

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

    my @pwd_dirs = File::Spec->splitdir(getcwd());
    my $project_name = $pwd_dirs[$#pwd_dirs];

    my @test_dirs = File::Spec->splitdir($test);

    my $test_dir = File::Spec->catfile(@test_dirs[0..$#test_dirs-1]);

    mkpath($test_dir);
    shift @test_dirs; # Удаляем t/
    $test_dirs[$#test_dirs] =~ s!\.t$!!; # Удаляем .t

    local $ENV{TMPDIR}; # yath устанавливает свою TMPDIR, нам этого не надо
    my $test_path = File::Spec->catfile(File::Spec->tmpdir, ".liveman", $project_name, join("!", @test_dirs));

    my $test_head1 = << 'END';
use common::sense;
use open qw/:std :utf8/;

use Carp qw//;
use File::Basename qw//;
use File::Find qw//;
use File::Slurper qw//;
use File::Spec qw//;
use File::Path qw//;
use Scalar::Util qw//;

use Test::More 0.98;

BEGIN {
    $SIG{__DIE__} = sub {
        my ($s) = @_;
        if(ref $s) {
            $s->{STACKTRACE} = Carp::longmess "?" if "HASH" eq Scalar::Util::reftype $s;
            die $s;
        } else {
            die Carp::longmess defined($s)? $s: "undef"
        }
    };

    my $t = File::Slurper::read_text(__FILE__);
    my $s = 
END

my $test_head2 = << 'END2';
    ;
    File::Find::find(sub { chmod 0700, $_ if !/^\.{1,2}\z/ }, $s), File::Path::rmtree($s) if -e $s;
    File::Path::mkpath($s);
    chdir $s or die "chdir $s: $!";
    push @INC, "lib";

    while($t =~ /^#\@> (.*)\n((#>> .*\n)*)#\@< EOF\n/gm) {
        my ($file, $code) = ($1, $2);
        $code =~ s/^#>> //mg;
        File::Path::mkpath(File::Basename::dirname($file));
        File::Slurper::write_text($file, $code);
    }

}
END2

    $test_head1 =~ y!\r\n!  !;
    $test_head2 =~ y!\r\n!  !;

    write_text $test, join "", $test_head1, "'", _q_esc($test_path), "'", $test_head2, @test;

    # Создаём модуль, если его нет
    my $pm = $md =~ s/\.md$/.pm/r;
    if(!-e $pm) {
        my $pkg = Liveman::Cpanfile::pkg_from_path $pm;
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

    $self->save_po;

    my $mark = join "", @text;
    $mark =~ s/^/!$from:$to/ if $from;
    write_text($md, $mark) if $mark ne $markdown;

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
        $self->{exit_code} = system "prove -Ilib -r t $options";
        #$self->{exit_code} = system "prove --exec 'echo `pwd`/lib && perl -MDevel::Cover -I`pwd`/lib' -r t";
    } else {
        $self->{exit_code} = system "$yath test -j4 --cover $options";
    }
    return $self if $self->{exit_code};
    system "$cover -report html_basic";
    system "(opera cover_db/coverage.html || xdg-open cover_db/coverage.html) &> /dev/null" if $self->{open};

    require Liveman::CoverBadge;
    eval {
        Liveman::CoverBadge->new->load->save;
    };
    warn $@ if $@;

    return $self;
}

1;

__END__

=encoding utf-8

=head1 NAME

Liveman - compiler from Markdown to tests and documentation

=head1 VERSION

3.2

=head1 SYNOPSIS

LIB/Example.md file:

	Дважды два:
	\```perl
	2*2  # -> 2+2
	\```

Test:

	use Liveman;
	
	my $liveman = Liveman->new(prove => 1);
	
	# Компилировать lib/Example.md файл в t/example.t 
	# и добавить pod-документацию в lib/Example.pm
	$liveman->transform("lib/Example.md");
	
	$liveman->{count}   # => 1
	-f "t/example.t"    # => 1
	-f "lib/Example.pm" # => 1
	
	# Компилировать все lib/**.md файлы со временем модификации, превышающим соответствующие тестовые файлы (t/**.t):
	$liveman->transforms;
	$liveman->{count}   # => 0
	
	# Компилировать без проверки времени модификации
	Liveman->new(compile_force => 1)->transforms->{count} # => 1
	
	# Запустить тесты с yath:
	my $yath_return_code = $liveman->tests->{exit_code};
	
	$yath_return_code           # => 0
	-f "cover_db/coverage.html" # => 1
	
	# Ограничить liveman этими файлами для операций, преобразований и тестов (без покрытия):
	my $liveman2 = Liveman->new(files => [], force_compile => 1);

=head1 DESCRIPION

The problem of modern projects is that the documentation is torn from testing.
This means that the examples in the documentation may not work, and the documentation itself can lag behind the code.

LiveMan compiles C<Lib/**. MD> to filesC<t/**. T>
And adds the documentation to the C<__end__> module to the filesC<LIB/**. PM>.

Use the `Liveman 'command to compilation of documentation for tests in the catalog of your project and start tests:

 liveman

Run it with a coating.

The C<-o> option opens a report on covering code with tests in a browser (coating report file:C<COVER_DB/Coverage.html>).

Liveman replaces the C<OUR $ Version =" ... ";> in C<LIB/**. Pm> fromC<Lib/**. MD> from the section I<* Version *> if it exists.

If the I<* minil.toml *> file exists, then Liveman will read C<NAME> from it and copy the file with this name and extensionC<.md> in C<readme.md>.

If you need the documentation in C<.md> to be written in one language, andC<pod> is on the other, then at the beginning of C<.md> you need to indicateC<! From: to> (from which language to translate, for example, for this file: C<! Ru: en>).

Headings (lines on #) - are not translated. Also, without translating the code blocks.
And the translation itself is carried out by paragraphs.

Files with transfers are added to the C<i18n> catalog, for example,C<Lib/my/Module.md> -> C<i18N/my/Module.ru-en.po>. Translation is carried out by the C<Trans> utility (it should be installed in the system). Translation files can be adjusted, because if the transfer is already in the file, then it is taken.

I<* Attention! *> Be careful and after editing C<.md> look atC<Git Diff> so as not to lose corrected translations in C<.Po>.

I<* Note: I<< > C<Trans -r> will show a list of languages that can be indicated in * >>! From: to ** on the first line of the document.

=head2 TYPES OF TESTS

Section codes without a specified programming language or with C<perl> are written as a code to the fileC<t/**. T>. And the comment with the arrow (# ->) turns into a test C<test :: more>.

=head3 C<is>

Compare two equivalent expressions:

	"hi!" # -> "hi" . "!"
	"hi!" # → "hi" . "!"

=head3 C<is_deeply>

Compare two expressions for structures:

	["hi!"] # --> ["hi" . "!"]
	"hi!" # ⟶ "hi" . "!"

=head3 C<is> with extrapolate-string

Compare the expression with an extrapolated line:

	my $exclamation = "!";
	"hi!2" # => hi${exclamation}2
	"hi!2" # ⇒ hi${exclamation}2

=head3 C<is> with nonextrapolate-string

Compare the expression with an unexpected line:

	'hi${exclamation}3' # \> hi${exclamation}3
	'hi${exclamation}3' # ↦ hi${exclamation}3

=head3 C<like>

Checks the regular expression included in the expression:

	'abbc' # ~> b+
	'abc'  # ↬ b+

=head3 C<unlike>

He checks the regular expression excluded from the expression:

	'ac' # <~ b+
	'ac' # ↫ b+

=head2 EMBEDDING FILES

Each test is performed in a temporary catalog, which is removed and created when starting the dough.

The format of this catalog: /tmp/.liveeman/I<Project>/I<Path-to-test>/.

The code section in the line with the MD-file prefix I<< * file C<Path>: * >> is written to the file when testing during execution.

The section of the code in the prefix line MD-file I<< * file C<Path> is: * >> will be compared with the fileC<test :: more :: is>.

Experiment/Test.txt file:

	hi!

Experiment/Test.txt file is:

	hi!

I<* Attention! *> An empty line between the prefix and the code is not allowed!

These prefixes can be both in English and in Russian (C<File [Path] (https://metacpan.org/pod/path):> and C<File [Path] (https://metacpan.org/pod/path) is:>).

=head1 METHODS

=head2 new (%param)

Constructor. Has arguments:

=over

=item 1. C<Files> (Array_ref)-a list of MD files for theC<transforms> and C<tests>.

=item 2. C<Open> (boolean) - open the coating in the browser. If the computer is installed on the computer I<* Opera *>, the C<Opera> command will be used to open. Otherwise-C<XDG-OPEN>.

=item 3. C<Force_compile> (Boolean)-do not check the time of modification of MD files.

=item 4. C<Options> - Add the parameters on the command line for verification or evidence.

=item 5. C<Prove> - use the proof (teamC<Prove> to start tests), and not the C<yath> command.

=back

=head2 test_path ($md_path)

Get the way to C<t/**. T>-file from the way toC<LIB/**. Md>-file:

	Liveman->new->test_path("lib/PathFix/RestFix.md") # => t/path-fix/rest-fix.t

=head2 transform ($md_path, [$test_path])

Compiles C<Lib/**. Md>-file inC<t/**. T>-file.

And also replaces I<* pod *>-the documentation in the C<__end__> section inC<LIB/**. PM>-file and creates C<LIB/**. Pm>-file, if it does not exist.

LIB/Example.pm file is:

	package Example;
	
	1;
	
	__END__
	
	=encoding utf-8
	
	Дважды два:
	
		2*2  # -> 2+2
	

The C<Lib/Example.pm> file was created from theC<Lib/Example.md> file, which is described in the `sinopsis' section in this document.

=head2 transforms ()

Compile C<Lib/**. Md>-files inC<t/**. T>-files.

That's all, if C<< $ self-E<gt> {files} >> is not installed, or C<< $ self-E<gt> {files} >>.

=head2 tests ()

Launch tests (C<t/**. T>-files).

That's all, if C<< $ self-E<gt> {files} >> is not installed, or C<< $ self-E<gt> {files} >> only.

=head2 load_po ($md, $from, $to)

Reads the PO-file.

=head2 save_po ()

Saves the PO-file.

=head2 trans ($text, $lineno)

The function translates the text from one language to another using the Trans utility.

=head2 trans_paragraph ($paragraph, $lineno)

It also breaks through paragraphs.

=head1 DEPENDENCIES IN CPANFILE

In your library, which you will test liveeman, you will need to indicate additional dependencies for tests in I<* cpanfile *>:

	on 'test' => sub {
	    requires 'Test::More', '0.98';
	
	    requires 'Carp';
	    requires 'File::Basename';
	    requires 'File::Path';
	    requires 'File::Slurper';
	    requires 'File::Spec';
	    requires 'Scalar::Util';
	};

It will also be good to indicate and the I<* liveman *> in the development section:

	on 'develop' => sub {
	    requires 'Minilla', 'v3.1.19';
	    requires 'Data::Printer', '1.000004';
	    requires 'Liveman', '1.0';
	};

=head1 AUTHOR

Yaroslav O. Kosmina L<mailto:dart@cpan.org>

=head1 LICENSE

⚖ I<* gplv3 *>

=head1 COPYRIGHT

The Liveman Module is Copyright © 2023 Yaroslav O. Kosmina. Rusland. All Rights Reserved.
