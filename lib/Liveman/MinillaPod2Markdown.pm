package Liveman::MinillaPod2Markdown;
# Обманка для Minilla, чтобы скопировать Module в README.md

@ISA = qw/Pod::Markdown/;

sub new { bless {}, shift }

sub parse_from_file {
    my ($self, $path) = @_;
    $self->{path} = $path =~ s!\.pm$!.md!r;
}

sub as_markdown {
    my ($self) = @_;
    open my $f, "<:utf8", $self->{path} or die "Not open file $self->{path}!";
    read $f, my $buf, -s $f;
    close $f;
    $buf
}

1;
