# This module implements a logger.

package Logger;

use strict;
use warnings FATAL => 'all';
use base qw(Exporter);
use Sys::Hostname;
use POSIX qw(strftime);
use URI::Encode qw(uri_encode);
use Time::HiRes qw(time);
use POSIX qw(strftime);

# See http://search.cpan.org/~toddr/Exporter-5.72/lib/Exporter.pm#Good_Practices
our @EXPORT = qw(critical
    fatal
    error
    warning
    info
    debug
    trace
    CRITICAL
    FATAL
    ERROR
    WARNING
    INFO
    DEBUG
    TRACE);
our %EXPORT_TAGS = (all => \@EXPORT);
our @EXPORT_OK = @EXPORT;

my $SESSION;

BEGIN {
    sub long_unique_id {
        my $t = time();
        my $date = strftime "%d%H%M%S", localtime $t;
        return sprintf('%d%d', $date, $$);
    }
    $SESSION = long_unique_id();
}

use constant CRITICAL => 0;
use constant FATAL    => 1;
use constant ERROR    => 2;
use constant WARNING  => 3;
use constant INFO     => 4;
use constant DEBUG    => 5;
use constant TRACE    => 6;

use constant FORMAT_DATE => '%Y%m%d-%H%M%S';

my %level2name = (
    &CRITICAL => 'CRI',
    &FATAL    => 'FAT',
    &ERROR    => 'ERR',
    &WARNING  => 'WAR',
    &INFO     => 'INF',
    &DEBUG    => 'DEB',
    &TRACE    => 'TRA');

# Create a logger.
# @param $inLogPath [string]
#        Path to the LOG file.
# @param $inLogLevel [int]
#        Log level. The value can be:
#        &CRITICAL: Log only critical errors.
#        &FATAL: Log fatal errors, and above (CRITICAL).
#        &ERROR: Log simple errors, and above (FATAL, CRITICAL).
#        &WARNING: Log warnings, and above (FATAL, CRITICAL, ERROR).
#        &INFO: Log informational message, and above (FATAL, CRITICAL, ERROR, WARNING).
#        &DEBUG: Log debug message, and above (FATAL, CRITICAL, ERROR, WARNING, INFO).
#        &TRACE: Log trace message, and above (FATAL, CRITICAL, ERROR, WARNING, INFO, DEBUG).
# @param $inOptSession [string]
#        Session value.

sub new {
    my ($inClassName, $inLogPath, $inLogLevel, $inOptSession) = @_;
    die("Unexpected value for the LOG level ($inLogLevel)") unless checkLogLevel($inLogLevel);

    my $self = {
        path => $inLogPath,
        level => $inLogLevel
    };

    if (defined($inOptSession)) {
        $SESSION = $inOptSession;
    }

    bless $self, $inClassName;
    return $self;
}

# Return the LOG session.
# @return [string]
#         The LOG session.

sub get_session {
    my ($self) = @_;
    return $SESSION
}

# LOG a critical message.
# @param $inMessage [string]
#        Message to LOG.

sub critical {
    my ($self, $inMessage) = @_;
    $self->__write(&CRITICAL, $inMessage);
}

# LOG a fatal message.
# @param $inMessage [string]
#        Message to LOG.

sub fatal {
    my ($self, $inMessage) = @_;
    $self->__write(&FATAL, $inMessage);
}

# LOG an error message.
# @param $inMessage [string]
#        Message to LOG.

sub error {
    my ($self, $inMessage) = @_;
    $self->__write(&ERROR, $inMessage);
}

# LOG a warning message.
# @param $inMessage [string]
#        Message to LOG.

sub warning {
    my ($self, $inMessage) = @_;
    $self->__write(&WARNING, $inMessage);
}

# LOG an informational message.
# @param $inMessage [string]
#        Message to LOG.

sub info {
    my ($self, $inMessage) = @_;
    $self->__write(&INFO, $inMessage);
}

# LOG a debug message.
# @param $inMessage [string]
#        Message to LOG.

sub debug {
    my ($self, $inMessage) = @_;
    $self->__write(&DEBUG, $inMessage);
}

# LOG a trace.
# @param $inMessage [string]
#        Message to LOG.

sub trace {
    my ($self, $inMessage) = @_;
    $self->__write(&TRACE, $inMessage);
}

# Write a message into the LOG file.
# @param $inLevel [int]
#        LOG level.
# @param $inMessage [string]
#        Message to log.

sub __write {
    my ($self, $inLevel, $inMessage) = @_;
    my $path = $self->{path};
    my $level = $self->{level};
    my $message = isMultiLine($inMessage) ? 'M ' . linearize($inMessage) : 'S ' . $inMessage;

    if ($inLevel > $level) { return 0; }

    open(my $fd, '>>', $path) or die("Can not open my LOG file \"$path\": $!");
    print $fd now() . ' ' . $SESSION . ' ' . $level2name{$inLevel} . ' ' . $message . "\n";
    if (isMultiLine($inMessage)) {
        $inMessage =~ s/^/\t# /gm;
        print $fd "${inMessage}\n";
    }
    close $fd;
    return 1;
}

sub checkLogLevel {
    my ($inLogLevel) = @_;
    return exists($level2name{$inLogLevel});
}

sub linearize {
    my ($inMessage) = @_;
    return uri_encode($inMessage);
}

sub isMultiLine {
    my ($inMessage) = @_;
    return $inMessage =~ m/\r|\n/;
}

sub now {
    return strftime(&FORMAT_DATE, localtime);
}

1;