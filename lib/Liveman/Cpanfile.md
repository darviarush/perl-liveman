# NAME

Liveman::Cpanfile - получение зависимостей

# SYNOPSIS

```perl
use Liveman::Cpanfile;

my $liveman_cpanfile = Liveman::Cpanfile->new;
```

# DESCRIPTION

Liveman::Cpanfile предназначен для получения всех используемых модулей в проекте для получения зависимостей которые затем будут добавлены в cpanfile. Он отбрасывает модули проекта и тестов, оставляя только зависимости.

# SUBROUTINES

## new ()

Конструктор

```perl
my $liveman_cpanfile = Liveman::Cpanfile->new;
$liveman_cpanfile->new  # -> .3
```

## pkg_from_path ()

Пакет из пути

```perl
my $liveman_cpanfile = Liveman::Cpanfile->new;
$liveman_cpanfile->pkg_from_path  # -> .3
```

## sc ()

Список файлов scripts/* и bin/*

```perl
my $liveman_cpanfile = Liveman::Cpanfile->new;
$liveman_cpanfile->sc  # -> .3
```

## pm ()

Список файлов lib/*.pm

```perl
my $liveman_cpanfile = Liveman::Cpanfile->new;
$liveman_cpanfile->pm  # -> .3
```

## mod ()

Список модулей проекта

```perl
my $liveman_cpanfile = Liveman::Cpanfile->new;
$liveman_cpanfile->mod  # -> .3
```

## md ()

Список *.md файлов

```perl
my $liveman_cpanfile = Liveman::Cpanfile->new;
$liveman_cpanfile->md  # -> .3
```

## md_mod ()

Список внедрённых в *.md модулей

```perl
my $liveman_cpanfile = Liveman::Cpanfile->new;
$liveman_cpanfile->md_mod  # -> .3
```

## deps ()

Список модулей-зависимостей явно указанных в скриптах и модулях (- mod)

```perl
my $liveman_cpanfile = Liveman::Cpanfile->new;
$liveman_cpanfile->deps  # -> .3
```

## t_deps ()

Список модулей-зависимостей из тестов (- deps - mod - md_mod)

```perl
my $liveman_cpanfile = Liveman::Cpanfile->new;
$liveman_cpanfile->t_deps  # -> .3
```

# INSTALL

For install this module in your system run next [command](https://metacpan.org/pod/App::cpm):

```sh
sudo cpm install -gvv Liveman::Cpanfile
```

# AUTHOR

Yaroslav O. Kosmina [dart@cpan.org](mailto:dart@cpan.org)

# LICENSE

⚖ **GPLv3**

# COPYRIGHT

The Liveman::Cpanfile module is copyright © 2025 Yaroslav O. Kosmina. Rusland. All rights reserved.
