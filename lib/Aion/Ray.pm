package Aion::Ray;
use 5.008001;
use strict;
use warnings;
use utf8;

our $VERSION = "0.01";

use Term::ANSIColor qw/colored/;
use File::Slurper qw/read_text write_text/;


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
    (($md =~ s/\.md$/.t/r) =~ s/^lib/t/r) =~ s/[A-Z]/"-".lc $&/gre
}

# Трансформирует md-файлы
sub transforms {
    my ($self) = @_;
    my $mds = $self->{files} // [split /\n/, `find lib -name '*.md'`];
    for my $md (@$mds) {
        my $test = $self->test_path($md);
        my $mdmtime = (stat $md)[9];
        die "Нет файла $md" if !$mdmtime;
        $self->transform($md, $test) if !-e $test || $mdmtime > (stat $test)[9];
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

# Трансформирует md-файл в тест и документацию
sub transform {
    my ($self, $md, $test) = @_;
    $test //= $self->test_path($md);

    print "🔖 $md ", colored("↦", "white"), " $test ", colored("...", "white"), " ";

    open my $f, "<:utf8", $md or die "$md: $!";
    _mkpath($test);
    open my $t, ">:utf8", $test or die "$test: $!";

    print $t "use strict; use warnings; use utf8; use open qw/:std :utf8/; use Test::More 0.98; ";

    my @markdown;
    my $close_subtest; my $title; my $use_title = 1;
    my $in_code; my $lang;

    while(<$f>) {
        push @markdown, $_;

        if($in_code) {
            if(/^```/) { # Закрываем код
                $in_code = 0;
                print $t "\n";
            }
            elsif($lang =~ /^(perl|)$/) {
                if(/#\s*((?<is_deeply>-->|⟶)|(?<is>->|→)|(?<qqis>=>|⇒)|(?<qis>\\>|↦))\s*(?<expected>.+?)\s*$/n) {
                    my ($code, $expected) = ($`, $+{expected});
                    my $q = do { _q_esc($_ =~ s!\s*$!!r) }; # Тут do, чтобы сохранить %+
                    $code = _trim($code);

                    print $t "\t"; # Начинаем строку с табуляции

                    if(exists $+{is_deeply}) { print $t "is_deeply do {$code}, do {$expected}, '$q';\n" }
                    elsif(exists $+{is})   { print $t "is do {$code}, do{$expected}, '$q';\n" }
                    elsif(exists $+{qqis}) { my $ex = _qq_esc($expected); print $t "is do {$code}, \"$ex\", '$q';\n" }
                    elsif(exists $+{qis})  { my $ex = _q_esc($expected);  print $t "is do {$code}, '$ex', '$q';\n" }
                    else { # Что-то ужасное вырвалось на волю!
                        print $t "???\n";
                    }
                }
                else { # Обычная строка кода
                    print $t "\t$_";
                }
            }
            else { # На каком-то другом языке
                print $t "# $_";
            }
        } else { # В тексте

            if(/^(#+)\s*/) { # Сохраняем заголовок
                $title = _trim($');
                print $t "# $_";
            }
            elsif(/^```(\w*)/) { # Открываем код

                $in_code = 1;
                $lang = $1;
                print $t "\n";

                if($use_title ne $title) {

                    print $t "done_testing; }; " if $close_subtest;
                    $close_subtest = 1;

                    my $title_q = _q_esc($title);
                    print $t "subtest '$title_q' => sub { ";

                    $use_title = $title;
                }
            }
            else { # Документацию печатаем в виде комментариев, чтобы сохранить нумерацию строк
                print $t "# $_";
            }
        }
    }

    print $t "\n\tdone_testing;\n};\n" if $close_subtest;
    print $t "\ndone_testing;\n";

    close $f;
    close $t;

    print colored("ok", "bright_green"), "\n";

    my $pm = $md =~ s/\.md$/.pm/r;
    if(!-e $pm) {
        my $pkg = ($pm =~ s!^lib/(.*)\.pm$!$1!r) =~ s!/!::!gr;
        write_text $pm, "package $pkg;\n\n1;";
    }

    use Markdown::To::POD 'markdown_to_pod';
    my $pod = markdown_to_pod(join "", @markdown);

    # Секции кода:
    $pod =~ s!^```(\w*)[\t ]*\n(.*?)^```[\t ]*\n! $2 =~ s/^/\t/gmr !gmse;
 
    my $module = read_text $pm;
    $module =~ s!(^__END__[\t ]*\n.*)?\z!
__END__

=encoding utf-8

$pod!smn;
    write_text $pm, $module;

    $self
}

# Запустить тесты
sub tests {
    my ($self) = @_;

    if($self->{files}) {
        return system "yath test -j4 @{$self->{files}}";
    }

    system "cover -delete";
    system "yath test -j4 --cover";
    system "cover";
    system "opera cover_db/coverage.html" if $self->{open};
}

1;
__END__

=encoding utf-8

=head1 NAME

Aion::Ray - markdown compiller to test and pod.

=head1 SYNOPSIS

    use Aion::Ray;

    my $ray = Aion::Ray->new;

    # compile lib/Example.md file to t/example.t and added pod to lib/Example.pm
    $ray->transform("lib/Example.md");

    # compile all lib/**.md files
    $ray->transforms;

    # start tests with yath
    $ray->tests;

    # limit ray to these files for operations transforms and tests (without cover)
    my $ray = Aion::Ray->new(files => ["lib/Example1.md", "lib/Examples/Example2.md"]);

=head1 DESCRIPTION

Aion::Ray compile lib/**.md files to t/**.t files
and it added pod-documentation to section __END__ to lib/**.pm files.

Use C<ray> command for compile:

    ray

=head1 LICENSE

Copyright (C) Yaroslav O. Kosmina.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Yaroslav O. Kosmina E<lt>darviarush@mail.ruE<gt>

=cut

