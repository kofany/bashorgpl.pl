use strict;
use warnings;
use LWP::UserAgent;
use HTML::Entities;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "1.5";
%IRSSI = (
    authors     => 'Twoje Imię',
    contact     => 'twój@email.com',
    name        => 'BashOrgScraper',
    description => 'Scrapuje cytaty z bash.org.pl i formatuje je dla IRC',
    license     => 'Public Domain',
    changed     => 'Data zmiany',
);

my $last_call_time = 0;
my $call_interval = 10; # czas w sekundach między kolejnymi wywołaniami

Irssi::signal_add('message public', 'handle_public');

sub handle_public {
    my ($server, $msg, $nick, $address, $target) = @_;
    if ($msg eq "!bash") {
        if (time - $last_call_time > $call_interval) {
            $last_call_time = time;
            my ($quote, $quote_number) = get_random_bash_quote();
            send_quote_in_parts($server, $target, $quote, $quote_number);
        } else {
            $server->command("msg $target Zaczekaj chwilę przed kolejnym użyciem !bash");
        }
    } elsif ($msg =~ /^!cytat (\d+)$/) {
        # Obsługa komendy !cytat z numerem cytatu
        my $quote_number = $1;
        if (time - $last_call_time > $call_interval) {
            $last_call_time = time;
            my $quote = get_quote_by_number($quote_number);
            send_quote_in_parts($server, $target, $quote, $quote_number);
        } else {
            $server->command("msg $target Zaczekaj chwilę przed kolejnym użyciem !cytat");
        }
    }
}
sub get_quote_by_number {
    my ($quote_number) = @_;
    my $ua = LWP::UserAgent->new;
    my $url = "http://bash.org.pl/$quote_number/";
    my $response = $ua->get($url);

    if ($response->is_success) {
        my $content = $response->decoded_content;
        if ($content =~ m{<div class="quote post-content post-body">(.*?)</div>}s) {
            my $quote = $1;
            $quote =~ s/<br\s*\/?>/\n/gi;
            $quote =~ s/<[^>]*>//g;
            $quote = decode_entities($quote);
            $quote =~ s/^\s+|\s+$//g;
            $quote =~ s/\t/    /g;
            return $quote;
        }
    }
    return "Nie udało się pobrać cytatu o numerze $quote_number.";
}


sub get_random_bash_quote {
    my $ua = LWP::UserAgent->new;
    my $response = $ua->get('http://bash.org.pl/random/');

    if ($response->is_success) {
        my $content = $response->decoded_content;
        my $quote_number;
        if ($content =~ m{<a class="qid click" href="/(\d+)/">#\d+</a>}s) {
            $quote_number = $1; # pobiera numer cytatu
        }
        if ($content =~ m{<div class="quote post-content post-body">(.*?)</div>}s) {
            my $quote = $1;
            $quote =~ s/<br\s*\/?>/\n/gi; # zamienia znaczniki <br> na nowe linie
            $quote =~ s/<[^>]*>//g; # usuwa pozostałe tagi HTML
            $quote = decode_entities($quote); # konwertuje encje HTML na znaki
            $quote =~ s/^\s+|\s+$//g; # usuwa białe znaki z początku i końca linii
            $quote =~ s/\t/    /g; # zamienia tabulatory na spacje
            return ($quote, $quote_number);
        }
    }
    return ("Nie udało się pobrać cytatu.", "");
}
sub send_quote_in_parts {
    my ($server, $target, $quote, $quote_number) = @_;
    my @lines = split /\n/, $quote;

    $server->command("msg $target [ cytat nr: #$quote_number]"); # nagłówek

    foreach my $line (@lines) {
        if ($line =~ /^\s*$/) {
            next; # pomija puste linie
        } 
        $server->command("msg $target $line");
    }

    $server->command("msg $target [ url http://bash.org.pl/$quote_number/ ]"); # stopka
}


Irssi::command_bind('bash', 'cmd_bash');

sub cmd_bash {
    my ($data, $server, $witem) = @_;
    if ($witem && ($witem->{type} eq "CHANNEL" || $witem->{type} eq "QUERY")) {
        if (time - $last_call_time > $call_interval) {
            $last_call_time = time;
            my $quote = get_random_bash_quote();
            send_quote_in_parts($server, $witem->{name}, $quote);
        } else {
            $witem->command("MSG ".$witem->{name}." Zaczekaj chwilę przed kolejnym użyciem !bash");
        }
    }
}
