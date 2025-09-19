requires 'perl', '5.22.0';

on 'test' => sub {
    requires 'Test::More', '0.98';

    requires 'Carp';
    requires 'common::sense';
    requires 'File::Basename';
    requires 'File::Find';
    requires 'File::Path';
    requires 'File::Slurper';
    requires 'File::Spec';
    requires 'Scalar::Util';
};

requires 'App::Prove';
requires 'App::Yath';
requires 'common::sense', '3.75';
requires 'Data::UUID', '1.226';
requires 'Devel::Cover', '1.40';
requires 'Carp';
requires 'Cwd::utf8', '0.011';
requires 'File::Basename';
requires 'File::Find::Wanted', '1.00';
requires 'File::Glob';
requires 'File::Path';
requires 'File::Slurper';
requires 'File::Spec';
requires 'File::Spec::Unix';
requires 'Getopt::Long', '2.58';
requires 'Locale::PO', '0.27';
requires 'Markdown::To::POD', '0.06';
requires 'Module::ScanDeps', '1.35';
requires 'Pod::Markdown';
requires 'Pod::Text', '5.01_02';
requires 'Pod::Usage', '2.03';
requires 'Scalar::Util', '1.63';
requires 'Term::ANSIColor', '5.01';
requires 'Template', '3.101';
requires 'Test::More', '0.98';
requires 'Text::Trim';
requires 'UUID', '0.37';
