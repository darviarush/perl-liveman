package Liveman::Cpanfile;

use common::sense;

use File::Find::Wanted qw/find_wanted/;
use File::Slurper qw/read_text write_text/;

# Конструктор
sub new {
	my $cls = shift;
	bless {@_}, ref $cls || $cls
}

# Пакет из пути
sub pkg_from_path(;$) {
    my ($pkg) = @_? @_: $_;
    my @pkg = File::Spec->splitdir($pkg);
    shift @pkg if $pkg[0] eq "lib"; # Удаляем lib/
    $pkg[$#pkg] =~ s!\.\w+$!!; # Удаляем расширение
    join "::", @pkg
}

# Список файлов scripts/* и bin/*
sub sc {
	my ($self) = @_;
	$self->{sc} //= [find_wanted(sub { -f $_ and -x _ }, "scripts", "bin")];
	wantarray? @{$self->{sc}}: $self->{sc}
}

# Список файлов lib/*.pm
sub pm {
	my ($self) = @_;
	$self->{pm} //= [find_wanted(sub { /\.pm$/ and -f $_ }, "lib")];
	wantarray? @{$self->{pm}}: $self->{pm}
}

# Список модулей проекта
sub mod {
    my ($self) = @_;
    $self->{mod} //= [map pkg_from_path, $self->pm];
	wantarray? @{$self->{mod}}: $self->{mod}
}

# Список *.md файлов
sub md {
    my ($self) = @_;
    $self->{md} //= [grep -e $_, map s!\.pm$!.md!r, $self->pm];
	wantarray? @{$self->{md}}: $self->{md}
}

# Список внедрённых в *.md модулей
sub md_mod {
    my ($self) = @_;
    $self->{md_mod} //= [do {
        my %mod;
        for my $md ($self->md) {
            my $f = read_text $_;
            $mod{$1}++ while $f =~ /\b([a-z]\w*(?:::[a-z]\w*){1,})\b/gi;
        }
        sort keys %mod
    }];
	wantarray? @{$self->{md_mod}}: $self->{md_mod}
}

# Считывает зависимости из файла
sub _read_deps(;$) {
	my ($file) = @_? @_: $_;

    my $f = read_text $file;
    my @mod;
    push @mod, pkg_from_path $1 while $f =~ /\brequire\s*['"]([\w\/\.]+)/g;
    push @mod, $1 while $f =~ /\b(?:use|require)\s+([\w:]+)/g;
    @mod
}

# Список модулей-зависимостей явно указанных в скриптах и модулях (- mod)
sub deps {
	my ($self) = @_;
	$self->{deps} //= do {
        my %mod = map ($_=>1), map _read_deps, $self->pm, $self->sc;
        delete @mod{$self->mod};
        [sort keys %mod]
	};
	wantarray? @{$self->{deps}}: $self->{deps}
}

# Список модулей-зависимостей из тестов (- deps - mod - md_mod)
sub t_deps {
	my ($self) = @_;
    $self->{t_deps} //= do {
        my %mod = map ($_=>1), map _read_deps, $self->test;
        delete @mod{$self->mod};
        [sort keys %mod]
	};
	wantarray? @{$self->{t_deps}}: $self->{t_deps}
}

# Записывает модули в cpanfile
sub _cpanfile {
	my ($self, $mds) = @_;

	return $self if !-e 'cpanfile';

    my $save = my $cpanfile = read_text 'cpanfile';

	require Module::ScanDeps;
    my $deps = Module::ScanDeps::scan_deps(
        files   => [find_wanted(sub { -f $_ }, "script"), map { s/\.md$/.pm/r } @$mds],
        recurse => 0,
    );

    my %deps = map { map {
        my $version;
        my $pm = $INC{$_};
        ($version) = read_text($pm) =~ /\$VERSION\s*=\s*([^\s;]+)/ if -f $pm;
        $version //= 0;
        $version =~ s/^["'](.*)["']$/$1/;
        $version = "'$version'";
        my $pkg = pkg_from_path $_;
        ($pkg => "requires '${pkg}', $version;\n")
    } grep { /\.pm$/ } @{$_->{uses}} } values %$deps;

	my @modules;
	$cpanfile =~ s!(?:^|\G)requires ['"]([\w:]+)[^;]*;\s*!
        if($1 eq "perl") { $& }
        else { $deps{$1} = $& if $deps{$1}; "" }
	!esgm;

	$cpanfile .= join "", sort {
        if($a =~ /^requires\s*'[a-z_]/ && $b =~ /^requires\s*'[A-Z]/) { -1 }
        elsif($b =~ /^requires\s*'[a-z_]/ && $a =~ /^requires\s*'[A-Z]/) { 1 }
        else { $a cmp $b }
    } values %deps;
    write_text("cpanfile", $cpanfile) if $cpanfile ne $save;

    my $is_warnings = 0;

    # Секция test
    if($cpanfile =~ /^on\s+['"]?test['"]?\s*=>(.*?)\n\};/ms) {
        my $test = $1;
        our @modules_for_test; my $i = 0;
        my %require = map { ($_ => $i++) } @modules_for_test;
        while($test =~ /requires\s*['"]([\w:]+)['"]/ag) {
            delete $require{$1};
        }

        if(keys %require) {
            $is_warnings = 1;
            my $add = join("",
                map { "    requires '$_';\n" }
                sort { $require{$a} <=> $require{$b} } keys %require
            );
            print "Add to section test modules in cpanfile:\n\n", $add, "\n";

#                 print "Add? [Y/n] ";
#                 if(scalar(<>) =~ /^(y|)$/i) {
#                     $cpanfile =~ s/^(on\s+['"]?test['"]?\s*=>.*?\n)(\};)/$1\n$add$2/ms;
#
#                     write_text 'cpanfile', $cpanfile;
#                     print "Added.\n";
#                 }
#                 else {
#                     print "\n";
# 	            }
        }
    }
    else {
        $is_warnings = 1;
        print "Not section test in cpanfile!\n";
    }

    $self
}

1;
