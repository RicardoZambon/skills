#!/usr/bin/env perl
# Report how the ADRs a document cites have moved since the document last checked them.
#
# Usage:
#   perl adr-drift.pl --register <repo> [--since <sha|YYYY-MM-DD>] [--ref origin/master]
#                     [--dir docs/decisions] [--no-fetch] doc.md [doc2.md ...]
#
# --register  a git checkout of the ADR register (default: $ADR_REGISTER).
# --since     the register commit or date the documents were checked against. Default:
#             the newest register commit SHA found in the documents, else the newest
#             date found next to the word "checked", else none (everything is "current").
# --ref       what to compare against (default origin/master, fetched first).
#
# Reports, per cited ADR: missing from the register, commits since the stamp, status now
# vs the status the document states, quotes that no longer appear in the current text,
# and citations by section, line or numbered item that will go stale. Then lists ADRs
# added to the register since the stamp, which the document cannot cite yet.
use strict;
use warnings;
use Getopt::Long;
use File::Spec;
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

my ($register, $since, $ref, $dir, $no_fetch) =
  ($ENV{ADR_REGISTER}, undef, 'origin/master', 'docs/decisions', 0);
GetOptions(
  'register=s' => \$register,
  'since=s'    => \$since,
  'ref=s'      => \$ref,
  'dir=s'      => \$dir,
  'no-fetch'   => \$no_fetch,
) or die "bad options\n";
die "usage: adr-drift.pl --register <repo> doc.md ...\n" unless $register && @ARGV;
die "not a git repo: $register\n" unless -d "$register/.git" || -f "$register/.git";

sub git {
  my @args = @_;
  # stderr is silenced: many lookups (a SHA from another repo) are expected to fail
  open(my $saved, '>&', \*STDERR) or die;
  open(STDERR, '>', File::Spec->devnull) or die;
  open(my $fh, '-|:encoding(UTF-8)', 'git', '-C', $register, @args) or die "git: $!\n";
  local $/;
  my $out = <$fh> // '';
  close $fh;
  open(STDERR, '>&', $saved) or die;
  return $out;
}

sub short_doc {
  my ($path) = @_;
  $path =~ s{.*[\\/]}{} if $ENV{ADR_DRIFT_FULL_PATHS} ? 0 : 1;
  return $path;
}

sub norm {
  my ($text) = @_;
  $text = lc $text;
  $text =~ s/\[([^\]]*)\]\([^)]*\)/$1/g;    # markdown links -> their text
  $text =~ s/[*_`>]//g;
  $text =~ s/[\x{2018}\x{2019}]/'/g;
  $text =~ s/[\x{201C}\x{201D}]/"/g;
  $text =~ s/[\x{2013}\x{2014}]/-/g;
  $text =~ s/\s+/ /g;
  $text =~ s/^\s+|\s+$//g;
  return $text;
}

unless ($no_fetch) {
  my ($remote, $branch) = split m{/}, $ref, 2;
  system('git', '-C', $register, 'fetch', '-q', $remote, $branch) == 0
    or warn "warning: fetch of $ref failed; comparing against the local copy\n";
}
my $head = git('rev-parse', '--short', $ref);
chomp $head;
die "unknown ref $ref in $register\n" unless $head;

# ---- read the documents ------------------------------------------------------------
my (%cited, @lines);    # %cited: number -> [doc:line, ...]
for my $doc (@ARGV) {
  open(my $fh, '<:encoding(UTF-8)', $doc) or die "cannot read $doc: $!\n";
  my $n = 0;
  my $in_code = 0;
  while (my $line = <$fh>) {
    $n++;
    chomp $line;
    $line =~ s/\r$//;
    $in_code = !$in_code if $line =~ /^\s*```/;
    my $name = short_doc($doc);
    push @lines, { doc => $name, n => $n, text => $line, code => $in_code };
    next if $in_code;
    while ($line =~ /\bADR[- ](\d{1,4})\b|adr-(\d{3,4})-[a-z0-9-]+\.md/gi) {
      my $num = sprintf('%03d', $1 // $2);
      push @{ $cited{$num} }, "$name:$n";
    }
  }
  close $fh;
}

# ---- attribute quotes ------------------------------------------------------------
# A quote (a quoted run of 20+ chars, or a blockquote line) belongs to the last ADR named
# before it on its line; failing that, the last one named in the three lines above.
my %quotes_by_adr;
{
  my $last_adr;
  my $last_seen = -99;
  for my $idx (0 .. $#lines) {
    my $line = $lines[$idx];
    next if $line->{code};
    my $text = $line->{text};
    my @events;    # [pos, type, value]
    push @events, [ $-[0], 'adr', sprintf('%03d', $1 // $2) ]
      while $text =~ /\bADR[- ](\d{1,4})\b|adr-(\d{3,4})-[a-z0-9-]+\.md/gi;
    push @events, [ $-[0], 'quote', $1 ]
      while $text =~ /["\x{201C}]([^"\x{201D}]{20,})["\x{201D}]/g;
    push @events, [ 0, 'quote', $1 ] if $text =~ /^\s*>\s*(.{20,})$/;
    for my $event (sort { $a->[0] <=> $b->[0] || ($a->[1] eq 'adr' ? -1 : 1) } @events) {
      if ($event->[1] eq 'adr') {
        ($last_adr, $last_seen) = ($event->[2], $idx);
      } elsif (defined $last_adr && $idx - $last_seen <= 3) {
        push @{ $quotes_by_adr{$last_adr} }, [ $line, $event->[2] ];
      }
    }
  }
}

# ---- resolve the stamp -------------------------------------------------------------
my $since_note = '';
unless ($since) {
  my (%shas, %dates);
  for my $line (@lines) {
    $shas{$1} = 1 while $line->{text} =~ /\b([0-9a-f]{7,40})\b/g;
    if ($line->{text} =~ /checked|read on|read again|as of/i) {
      $dates{$1} = 1 while $line->{text} =~ /\b(20\d\d-\d\d-\d\d)\b/g;
    }
  }
  my ($best, $best_time) = (undef, 0);
  for my $sha (keys %shas) {
    my $out = git('log', '-1', '--format=%ct', "$sha^{commit}", '--');
    next unless $out =~ /^(\d+)/;
    next unless git('merge-base', '--is-ancestor', $sha, $ref) eq ''
      && $? == 0;
    ($best, $best_time) = ($sha, $1) if $1 > $best_time;
  }
  if ($best) {
    $since = $best;
    $since_note = 'newest register commit named in the documents';
  } elsif (%dates) {
    my ($date) = sort { $b cmp $a } keys %dates;
    my $sha = git('rev-list', '-1', "--before=$date 23:59:59", $ref);
    chomp $sha;
    if ($sha) {
      $since = $sha;
      $since_note = "last register commit on $date, the newest \"checked\" date in the documents";
    }
  }
}
my $since_short = '';
if ($since) {
  if ($since =~ /^20\d\d-\d\d-\d\d$/) {
    my $sha = git('rev-list', '-1', "--before=$since 23:59:59", $ref);
    chomp $sha;
    die "no register commit on or before $since\n" unless $sha;
    $since_note ||= "last register commit on $since";
    $since = $sha;
  }
  $since_short = git('rev-parse', '--short', $since);
  chomp $since_short;
  die "unknown --since commit $since\n" unless $since_short;
  $since_note ||= 'given with --since';
}

# ---- register state ----------------------------------------------------------------
my %file_at_ref;
for my $path (split /\n/, git('ls-tree', '-r', '--name-only', $ref, '--', $dir)) {
  $file_at_ref{$1} = $path if $path =~ m{/adr-(\d{3,4})-[^/]*\.md$};
}

sub frontmatter {
  my ($rev, $path) = @_;
  my $text = git('show', "$rev:$path");
  my %fm;
  if ($text =~ /\A---\r?\n(.*?)\r?\n---/s) {
    for (split /\r?\n/, $1) { $fm{$1} = $2 if /^([a-z_]+):\s*(.*?)\s*$/ }
  }
  return (\%fm, $text);
}

sub file_at_since {
  my ($num) = @_;
  return undef unless $since;
  for my $path (split /\n/, git('ls-tree', '-r', '--name-only', $since, '--', $dir)) {
    return $path if $path =~ m{/adr-$num-[^/]*\.md$};
  }
  return undef;
}

# ---- report ------------------------------------------------------------------------
print "# ADR drift report\n\n";
print "Register: $register at $ref ($head).\n";
print $since
  ? "Checked against: $since_short ($since_note).\n\n"
  : "Checked against: no stamp found. Every ADR is compared as it is now. Pass --since.\n\n";

my @nums = sort keys %cited;
my %summary = (missing => 0, changed => 0, status => 0, quote => 0, fragile => 0);

for my $num (@nums) {
  my @where = @{ $cited{$num} };
  my $path  = $file_at_ref{$num};
  print "## ADR-$num\n\n";
  unless ($path) {
    $summary{missing}++;
    print "- NOT ON $ref. A draft, a pull request, or a wrong number. Cited at: "
      . join(', ', @where[0 .. ($#where < 4 ? $#where : 4)]) . ".\n\n";
    next;
  }
  my ($fm, $text) = frontmatter($ref, $path);
  my $status = $fm->{status} // '?';
  print "- Title: " . ($fm->{title} // '?') . ". Status now: $status. Services: "
    . ($fm->{services} // '?') . ".\n";
  print "- Cited " . scalar(@where) . " times, first at $where[0].\n";

  if ($since) {
    my $old = file_at_since($num);
    if (!$old) {
      print "- ADDED after the stamp. The documents cite it but were not checked against it.\n";
      $summary{changed}++;
    } else {
      my ($old_fm) = frontmatter($since, $old);
      my $old_status = $old_fm->{status} // '?';
      my $log = git('log', '--format=  - %h %cs %s', "$since..$ref", '--', $old, $path);
      if ($log) {
        $summary{changed}++;
        print "- CHANGED since the stamp:\n$log";
        print "- Status was $old_status, now $status.\n" if $old_status ne $status;
        my $diff = git('diff', '-U0', $since, $ref, '--', $old, $path);
        my @added = grep { /^\+(?!\+\+)/ && /\b(amend|supersed|history|status|replac|reject|withdr)/i }
          split /\n/, $diff;
        if (@added) {
          print "- Added lines that look like amendments or status changes:\n";
          for my $line (@added[0 .. ($#added < 7 ? $#added : 7)]) {
            my $short = substr($line, 1, 220);
            print "  > $short\n";
          }
        }
      } else {
        print "- Unchanged since the stamp.\n";
      }
    }
  }

  # statuses the documents state next to the citation, e.g. "[ADR-030](...) (Proposed)"
  my $ntext = norm($text);
  for my $line (grep { !$_->{code} } @lines) {
    my $raw = $line->{text};
    while ($raw =~ /ADR[- ]0*\Q@{[$num + 0]}\E\b(?:\]\([^)]*\))?\s*\((Accepted|Proposed|Superseded|Deprecated|Rejected|Draft)\b/gi) {
      my $said = $1;
      if (lc $said ne lc((split /\s+/, $status)[0])) {
        $summary{status}++;
        print "- STATUS: $line->{doc}:$line->{n} says \"$said\", the register says \"$status\".\n";
      }
    }
  }

  # quotes attributed to this ADR (the nearest ADR named before the quote) that no
  # longer appear in its current text
  for my $quote_ref (@{ $quotes_by_adr{$num} || [] }) {
    my ($line, $quote) = @$quote_ref;
    {
      my $nq = norm($quote);
      next if ($nq =~ tr/ //) < 4;
      next if index($ntext, $nq) >= 0;
      # tolerate an ellipsis: every fragment must still be there
      my @parts = grep { length($_) > 12 } map { norm($_) } split /\.\.\.|\x{2026}/, $quote;
      next if @parts > 1 && !grep { index($ntext, $_) < 0 } @parts;
      $summary{quote}++;
      my $show = length($quote) > 120 ? substr($quote, 0, 117) . '...' : $quote;
      print "- QUOTE not in the current text, $line->{doc}:$line->{n}: \"$show\"\n";
    }
  }

  # citations that point inside the ADR by position
  for my $line (grep { !$_->{code} } @lines) {
    my $raw = $line->{text};
    $raw =~ s/\]\([^)]*\)/]/g;    # drop link targets so "near" means near in the prose
    my @hits;
    # a position inside the ADR: "ADR-006 §3", "ADR-006, rule 10", "ADR-006's decision 3",
    # "line 40 of ADR-006", "adr-006-....md:40"
    my $pos = qr/\x{00A7}\s*[\d.]+|\blines? \d+|\b(?:decision|rule|condition|item|section|option|point|step) \d+\b/i;
    my $adr = qr/ADR[- ]0*\Q@{[$num + 0]}\E\b\]?/i;
    push @hits, $1 while $raw =~ /$adr(?:'s)?[^.;:()\[]{0,25}?($pos)/g;
    push @hits, $1 while $raw =~ /($pos)\s+(?:of|in)\s+(?:the\s+)?\[?$adr/g;
    push @hits, $1 while $raw =~ /(adr-$num-[a-z0-9-]+\.md:\d+)/gi;
    next unless @hits;
    $summary{fragile}++;
    print "- POSITIONAL citation, $line->{doc}:$line->{n}: " . join(', ', @hits) . "\n";
  }
  print "\n";
}

if ($since) {
  my $added = git('log', '--diff-filter=A', '--name-only', '--format=', "$since..$ref", '--', $dir);
  my @new = grep { m{/adr-(\d{3,4})-[^/]*\.md$} && !$cited{$1} } split /\n/, $added;
  if (@new) {
    print "## ADRs added since the stamp and not cited\n\n";
    print "Check each for relevance; a new Accepted ADR may bind the design.\n\n";
    for my $path (@new) {
      next unless git('cat-file', '-t', "$ref:$path") =~ /blob/;
      my ($fm) = frontmatter($ref, $path);
      my ($num) = $path =~ m{/adr-(\d+)-};
      print "- ADR-$num: " . ($fm->{title} // '?') . ". Status: " . ($fm->{status} // '?')
        . ". Services: " . ($fm->{services} // '?') . ".\n";
    }
    print "\n";
  }
}

# editing accidents: a regex backreference left in the text, placeholders, draft numbers
my @accidents = grep {
  !$_->{code} && $_->{text} =~ /(?:^|\s)\$\d\b|\bTODO\b|\bTBD\b|\bADR-XXX\b|\bXXX\b/
} @lines;
if (@accidents) {
  print "## Leftovers\n\n";
  for my $line (@accidents) {
    my $show = substr($line->{text}, 0, 140);
    print "- $line->{doc}:$line->{n}: $show\n";
  }
  print "\n";
}

print "## Summary\n\n";
printf "%d ADRs cited. Not on %s: %d. Changed or added since the stamp: %d. Status mismatches: %d. "
  . "Stale quotes: %d. Positional citations: %d.\n",
  scalar(@nums), $ref, @summary{qw(missing changed status quote fragile)};
