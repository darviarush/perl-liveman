package Liveman::TestEnv;
# Настраивает окружение теста
use Liveman::Util qw//;
use File::Slurper qw/read_text write_text/;

# Вызывается из теста
sub import {
    my ($pkg, $test) = caller;

    my $project_path = `pwd`;
    chop $project_path;
    my ($project) = $project_path =~ m!([^/]*)$!;

    my $test_path = "/tmp/.liveman/$project" . ($test =~ s!^t/(.*)\.t$!/$1/!r);

    `rm -fr $test_path` if -e $test_path;

    Liveman::Util::mkpath($test_path);

    # Теперь переписываем файлы теста в $test_path
    my $code = read_text $test;
    while($code =~ /^#\@> (.*)\n((?:#>> .*\n)*)#\@< EOF\n/gm) {
        my ($file, $text) = ($1, $2);
        $text =~ s!^#>> !!mg;
        my $path = Liveman::Util::mkpath($test_path . $file);
        write_text $path, $text;
    }

    chdir $test_path or die "chdir $test_path: $!";
}

1;