#!/usr/bin/env perl
# Flag text that breaks the writing rules in ../rules.md.
#
# Usage: perl check-prose.pl [--max-words N] [FILE ...]
#        (no FILE, or "-", reads stdin)
#
# Reports section-sign citations, file:line code locations, bare commit
# hashes, ticket/ADR/PR/MR references without a link, and sentences longer
# than --max-words (default 25). Skips YAML front matter, fenced code blocks
# and everything under a "References" heading, where locations and hashes
# belong. It is a pattern match: a reader decides whether each hit is real.
#
# Exit status: 0 clean, 1 findings, 2 usage error.
use strict;
use warnings;
use utf8;
use Getopt::Long;

binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

my $max_words = 25;
GetOptions('max-words=i' => \$max_words) or usage();
usage() if $max_words < 1;
@ARGV = ('-') unless @ARGV;

# Hyphenated names that look like ticket keys but are not.
my %not_keys = map { $_ => 1 } qw(UTF SHA ISO MD ES TLS SSL HTTP IEC EN IPV WCAG COVID);
my $ext = qr/(?:cs|vb|ts|tsx|js|jsx|mjs|cjs|vue|py|rb|go|rs|java|kt|swift|c|h|cc|cpp|hpp|sql|ps1|psm1|sh|bash|ya?ml|json|xml|md|html?|css|scss|less|csproj|sln|cshtml|razor|tf|toml|ini|cfg|config|resx|xaml|txt|php|gradle)/i;
my $url = qr{<?https?://[^\s>)]+>?};

my ($label, @para);
my $findings = 0;

for my $path (@ARGV) {
    my $fh;
    if ($path eq '-') {
        $fh = \*STDIN;
        binmode $fh, ':encoding(UTF-8)';
        $label = 'stdin';
    } else {
        open $fh, '<:encoding(UTF-8)', $path
            or do { print STDERR "check-prose: cannot read $path: $!\n"; exit 2 };
        $label = $path;
    }

    my ($n, $fence, $refs_level, $front) = (0, undef, 0, 0);
    while (my $line = <$fh>) {
        $n++;
        $line =~ s/\r?\n\z//;

        if ($n == 1 && $line eq '---') { $front = 1; next; }
        if ($front) { $front = 0 if $line eq '---'; next; }
        $line =~ s/^\s*(?:>\s?)+//;    # quoted text is checked like any other

        if (defined $fence) { undef $fence if $line =~ /^\s*\Q$fence\E\s*$/; next; }
        if ($line =~ /^\s*(`{3,}|~{3,})/) { flush(); $fence = $1; next; }

        if ($line =~ /^(#{1,6})\s+(.*)/) {
            flush();
            my ($level, $title) = (length $1, $2);
            $refs_level = 0 if $refs_level && $level <= $refs_level;
            if (!$refs_level && $title =~ /^\W*references\b/i) { $refs_level = $level; next; }
            check_line($n, $title) unless $refs_level;
            next;
        }
        if ($line =~ /^\s*(?:\*\*|__)?references(?:\*\*|__)?:?\s*$/i) { flush(); $refs_level = 7; next; }
        next if $refs_level;

        if ($line =~ /^\s*$/) { flush(); next; }
        if ($line =~ /^\s*\|/) { flush(); check_line($n, $line); next; }
        flush() if $line =~ /^\s*(?:[-*+]|\d+[.)])\s+/;

        check_line($n, $line);
        push @para, [$n, $line];
    }
    flush();
    close $fh unless $path eq '-';
}

exit($findings ? 1 : 0);

sub usage {
    print STDERR "usage: perl check-prose.pl [--max-words N] [FILE ...]\n";
    exit 2;
}

sub report {
    my ($n, $kind, $what, $hint) = @_;
    $findings++;
    print "$label:$n: $kind: \"$what\" ($hint)\n";
}

# Checks that work on a single line.
sub check_line {
    my ($n, $text) = @_;

    # What the reader sees: link text stays, link targets and bare URLs go.
    (my $visible = $text) =~ s/\]\([^)]*\)/]/g;
    $visible =~ s/$url//g;
    # What is left once every link is removed: a reference here has no link.
    (my $unlinked = $text) =~ s/\[[^\]]*\]\([^)]*\)//g;
    $unlinked =~ s/$url//g;

    # A § inside inline code is an example, like the one in rules.md.
    (my $prose = $visible) =~ s/`[^`]*`//g;
    while ($prose =~ /(§\s*[\w.]*)/g) {
        report($n, 'section-cite', $1, 'explain the idea instead');
    }
    while ($visible =~ /([\w.\/\\~-]+\.$ext(?::\d+(?:[:-]\d+)?|#L\d+))(?![\w.])/g) {
        report($n, 'code-location', $1, 'move it to a References section');
    }
    while ($visible =~ /(?<![\w\/#.-])((?=[0-9a-f]*[a-f])(?=[0-9a-f]*[0-9])[0-9a-f]{7,40})(?![\w-])/g) {
        report($n, 'commit-id', $1, 'say what the commit did; keep the hash in References');
    }

    my $hint = 'link it with its full URL';
    $unlinked =~ s/\b((?:PR|MR)\s*[#!]?\d+)\b/report($n, 'unlinked-ref', $1, $hint); ' ' x length $1/ge;
    while ($unlinked =~ /(?<![\w\/.-])([A-Z][A-Z0-9]{1,9})-(\d+)(?![\w-])/g) {
        report($n, 'unlinked-ref', "$1-$2", $hint) unless $not_keys{$1};
    }
    while ($unlinked =~ /(?<![\w&!])(![0-9]+)\b/g) { report($n, 'unlinked-ref', $1, $hint); }
    while ($unlinked =~ /(?<![\w&#])(#[0-9]+)\b/g) { report($n, 'unlinked-ref', $1, $hint); }
}

# Sentence length, checked per paragraph or list item so wrapped lines join up.
sub flush {
    return unless @para;
    my $start = $para[0][0];
    my $text = join ' ', map { $_->[1] } @para;
    @para = ();

    $text =~ s/^\s*(?:[-*+]|\d+[.)])\s+//;
    $text =~ s/\]\([^)]*\)/]/g;
    $text =~ s/$url/URL/g;
    # Move closing markup before the full stop, so "done.**" ends a sentence.
    $text =~ s/([.!?])([*_)"'\x{201D}\x{2019}]+)(?=\s|$)/$2$1/g;

    for my $sentence (split /(?<=[.!?])\s+/, $text) {
        my @words = grep { /\w/ } split /\s+/, $sentence;
        next if @words <= $max_words;
        my $opening = join ' ', @words[0 .. 7];
        report($start, 'long-sentence', "$opening ...", scalar(@words) . " words; split it");
    }
}
