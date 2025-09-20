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
use Liveman::MinillaPod2Markdown;

# Конструктор
sub new {
    my $cls = shift;
    my $self = bless {@_}, $cls;
    delete $self->{files} if $self->{files} && !scalar @{$self->{files}};
	$self->{pod2markdown} = Liveman::MinillaPod2Markdown->new;
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
            ($name) = $minil =~ /^name\s*=\s*"([\w:-]+)"/m;
            $name =~ s!(-|::)!/!g;
            $name = "lib/$name.md";
            if(-f $name && -r $name) {
                if(!-e "README.md" || $self->{compile_force} || (stat $name)[9] > (stat "README.md")[9]) {
                    my $readme = $self->{pod2markdown}->parse_from_file($name =~ s/\.\w+$/.pm/r)->as_markdown;
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

	my $yath; my $prove;
	my $use_prove = $self->{prove};
	if($use_prove) {
		$prove = "/usr/bin/site_perl/prove";
		$prove = 'prove' if !-e $prove;
	} else {
		$yath = "/usr/bin/site_perl/yath";
		$yath = 'yath' if !-e $yath;
	}

    my $options = $self->{options};

    if($self->{files}) {
        my @tests = map $self->test_path($_), @{$self->{files}};
        local $, = " ";
        $self->{exit_code} = system $use_prove
            ? "$prove -Ilib $options @tests"
            : "$yath test -j4 $options @tests";
        return $self;
    }

    my $perl5opt = $ENV{PERL5OPT};
	{
		local $ENV{PERL5OPT};
		system "$cover -delete";
		if($use_prove) {
			local $ENV{PERL5OPT} = "$perl5opt -MDevel::Cover";
			$self->{exit_code} = system "$prove -Ilib -r t $options";
			#$self->{exit_code} = system "prove --exec 'echo `pwd`/lib && perl -MDevel::Cover -I`pwd`/lib' -r t";
		} else {
			$self->{exit_code} = system "$yath test -j4 --cover $options";
		}
		return $self if $self->{exit_code};
		system "$cover -report html_basic";
		system "(opera cover_db/coverage.html || xdg-open cover_db/coverage.html) &> /dev/null" if $self->{open};
	}

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

!ru:en,badges
=head1 NAME

Liveman - компиллятор из markdown в тесты и документацию

=head1 VERSION

3.2

=head1 SYNOPSIS

Файл lib/Example.md:

	Twice two:
	\```perl
	2*2  # -> 2+2
	\```

Тест:

	use Liveman;
	
	my $liveman = Liveman->new(prove => 1);
	
	$liveman->transform("lib/Example.md");
	
	$liveman->{count}   # => 1
	-f "t/example.t"    # => 1
	-f "lib/Example.pm" # => 1
	
	$liveman->transforms;
	$liveman->{count}   # => 0
	
	Liveman->new(compile_force => 1)->transforms->{count} # => 1
	
	my $prove_return_code = $liveman->tests->{exit_code};
	
	$prove_return_code           # => 0
	-f "cover_db/coverage.html" # => 1

=head1 DESCRIPION

Проблема современных проектов в том, что документация оторвана от тестирования.
Это значит, что примеры в документации могут не работать, а сама документация может отставать от кода.

Liveman компилирует файлы C<lib/**.md> в файлы C<t/**.t>
и добавляет документацию в раздел C<__END__> модуля к файлам C<lib/**.pm>.

Используйте команду C<liveman> для компиляции документации к тестам в каталоге вашего проекта и запускайте тесты:

 liveman

Запустите его с покрытием.

Опция C<-o> открывает отчёт о покрытии кода тестами в браузере (файл отчёта покрытия: C<cover_db/coverage.html>).

Liveman заменяет C<our $VERSION = "...";> в C<lib/**.pm> из C<lib/**.md> из секции B<VERSION> если она существует.

Если файл B<minil.toml> существует, то Liveman прочитает из него C<name> и скопирует файл с этим именем и расширением C<.md> в C<README.md>.

Если нужно, чтобы документация в C<.md> была написана на одном языке, а C<pod> – на другом, то в начале C<.md> нужно указать C<!from:to> (с какого на какой язык перевести, например, для этого файла: C<!ru:en>).

Заголовки (строки на #) – не переводятся. Так же не переводятя блоки кода.
А сам перевод осуществляется по абзацам.

Файлы с переводами складываются в каталог C<i18n>, например, C<lib/My/Module.md> -> C<i18n/My/Module.ru-en.po>. Перевод осуществляется утилитой C<trans> (она должна быть установлена в системе). Файлы переводов можно подкорректировать, так как если перевод уже есть в файле, то берётся он.

B<Внимание!> Будьте осторожны и после редактирования C<.md> просматривайте C<git diff>, чтобы не потерять подкорректированные переводы в C<.po>.

B<Примечание:> C<trans -R> покажет список языков, которые можно указывать в B<!from:to> на первой строке документа.

=head2 TYPES OF TESTS

Коды секций без указанного языка программирования или с C<perl> записываются как код в файл C<t/**.t>. А комментарий со стрелкой (# -> )превращается в тест C<Test::More>.

=head3 C<is>

Сравнить два эквивалентных выражения:

	"hi!" # -> "hi" . "!"
	"hi!" # → "hi" . "!"

=head3 C<is_deeply>

Сравнить два выражения для структур:

	["hi!"] # --> ["hi" . "!"]
	"hi!" # ⟶ "hi" . "!"

=head3 C<is> with extrapolate-string

Сравнить выражение с экстраполированной строкой:

	my $exclamation = "!";
	"hi!2" # => hi${exclamation}2
	"hi!2" # ⇒ hi${exclamation}2

=head3 C<is> with nonextrapolate-string

Сравнить выражение с неэкстраполированной строкой:

	'hi${exclamation}3' # \> hi${exclamation}3
	'hi${exclamation}3' # ↦ hi${exclamation}3

=head3 C<like>

Проверяет регулярное выражение, включенное в выражение:

	'abbc' # ~> b+
	'abc'  # ↬ b+

=head3 C<unlike>

Он проверяет регулярное выражение, исключённое из выражения:

	'ac' # <~ b+
	'ac' # ↫ b+

=head2 EMBEDDING FILES

Каждый тест выполняется во временном каталоге, который удаляется и создается при запуске теста.

Формат этого каталога: /tmp/.liveman/I<project>/I<path-to-test>/.

Раздел кода в строке с префиксом md-файла B<< File C<path>: >> запишется в файл при тестировании во время выполнения.

Раздел кода в префиксной строке md-файла B<< File C<path> is: >> будет сравниваться с файлом методом C<Test::More::is>.

Файл experiment/test.txt:

	hi!

Файл experiment/test.txt является:

	hi!

B<Внимание!> Пустая строка между префиксом и кодом не допускается!

Эти префиксы могут быть как на английском, так и на русском (C<File [path](https://metacpan.org/pod/path):> и C<File [path](https://metacpan.org/pod/path) is:>).

=head1 METHODS

=head2 new (%param)

Конструктор. Имеет аргументы:

=over

=item 1. C<files> (array_ref) — список md-файлов для методов C<transforms> и C<tests>.

=item 2. C<open> (boolean) — открыть покрытие в браузере. Если на компьютере установлен браузер B<opera>, то будет использоватся команда C<opera> для открытия. Иначе — C<xdg-open>.

=item 3. C<force_compile> (boolean) — не проверять время модификации md-файлов.

=item 4. C<options> — добавить параметры в командной строке для проверки или доказательства.

=item 5. C<prove> — использовать доказательство (команду C<prove> для запуска тестов), а не команду C<yath>.

=back

=head2 test_path ($md_path)

Получить путь к C<t/**.t>-файлу из пути к C<lib/**.md>-файлу:

	Liveman->new->test_path("lib/PathFix/RestFix.md") # => t/path-fix/rest-fix.t

=head2 transform ($md_path, [$test_path])

Компилирует C<lib/**.md>-файл в C<t/**.t>-файл.

А так же заменяет B<pod>-документацию в секции C<__END__> в C<lib/**.pm>-файле и создаёт C<lib/**.pm>-файл, если тот не существует.

Файл lib/Example.pm является:

	package Example;
	
	1;
	
	__END__
	
	=encoding utf-8
	
	Twice two:
	
		2*2  # -> 2+2
	

Файл C<lib/Example.pm> был создан из файла C<lib/Example.md>, что описано в разделе C<SINOPSIS> в этом документе.

=head2 transforms ()

Компилировать C<lib/**.md>-файлы в C<t/**.t>-файлы.

Все, если C<< $self-E<gt>{files} >> не установлен, или C<< $self-E<gt>{files} >>.

=head2 tests ()

Запустить тесты (C<t/**.t>-файлы).

Все, если C<< $self-E<gt>{files} >> не установлен, или C<< $self-E<gt>{files} >> только.

=head2 load_po ($md, $from, $to)

Считывает po-файл.

=head2 save_po ()

Сохраняет po-файл.

=head2 trans ($text, $lineno)

Функция переводит текст с одного языка на другой используя утилиту trans.

=head2 trans_paragraph ($paragraph, $lineno)

Так же разбивает по параграфам.

=head1 DEPENDENCIES IN CPANFILE

В своей библиотеке, которую вы будете тестировать Liveman-ом, нужно будет указать дополнительные зависимости для тестов в B<cpanfile>:

	on 'test' => sub {
	    requires 'Test::More', '0.98';
	
	    requires 'Carp';
	    requires 'File::Basename';
	    requires 'File::Path';
	    requires 'File::Slurper';
	    requires 'File::Spec';
	    requires 'Scalar::Util';
	};

Так же неплохо будет указать и сам B<Liveman> в разделе для разработки:

	on 'develop' => sub {
	    requires 'Minilla', 'v3.1.19';
	    requires 'Data::Printer', '1.000004';
	    requires 'Liveman', '1.0';
	};

=head1 AUTHOR

Yaroslav O. Kosmina L<mailto:dart@cpan.org>

=head1 LICENSE

⚖ B<GPLv3>

=head1 COPYRIGHT

The Liveman module is copyright © 2023 Yaroslav O. Kosmina. Rusland. All rights reserved.
