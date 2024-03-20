# This module implements a logger.

package Logger;

use strict;
use warnings FATAL => 'all';
use base qw(Exporter);
use Sys::Hostname;
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
    TRACE
    get_log_level_from_name
    get_log_name_from_level
    get_all_level_names);
our %EXPORT_TAGS = (all => \@EXPORT);
our @EXPORT_OK = @EXPORT;

use constant CRITICAL => 0;
use constant FATAL    => 1;
use constant ERROR    => 2;
use constant WARNING  => 3;
use constant INFO     => 4;
use constant DEBUG    => 5;
use constant TRACE    => 6;

use constant FORMAT_DATE => '%Y%m%d-%H%M%S';

use constant NAME2LEVEL => {
    'CRI' => &CRITICAL,
    'FAT' => &FATAL,
    'ERR' => &ERROR,
    'WAR' => &WARNING,
    'INF' => &INFO,
    'DEB' => &DEBUG,
    'TRA' => &TRACE
};

use constant LEVEL2NAME => {
    &CRITICAL => 'CRI',
    &FATAL    => 'FAT',
    &ERROR    => 'ERR',
    &WARNING  => 'WAR',
    &INFO     => 'INF',
    &DEBUG    => 'DEB',
    &TRACE    => 'TRA'
};

# Create a unique UD.
#
# @return A unique ID.

sub unique_id {
    my $t = time();
    my $date = strftime "%d%H%M%S", localtime $t;
    return sprintf('%d%d', $date, $$);
}

# Return the (numerical) LOG level associate with a given level name.
#
# @param $name The name of the LOG level.
#        May be: "CRI", "FAT", "ERR", "WAR", "INF", "DEB", "TRA"
# @return The (numerical) LOG level associate with the given level name.
#         If the given name is unexpected, then the function returns the value undef.

sub get_log_level_from_name {
    my ($name) = @_;
    $name = uc($name);
    return(&NAME2LEVEL->{$name}) if (exists(&NAME2LEVEL->{$name}));
    return(undef);
}

# Return the name of the LOG level associate with a given numerical level.
#
# @param $level The numerical LOG level.
# @return The name of the LOG level associate with a given numerical level.
#         May be: "CRI", "FAT", "ERR", "WAR", "INF", "DEB", "TRA"
#         If the given level is unexpected, then the function returns the value undef.

sub get_log_name_from_level {
    my ($level) = @_;
    return(&LEVEL2NAME->{$level}) if (exists(&LEVEL2NAME->{$level}));
    return(undef);
}

# Return he list of all LOG level names.
#
# @return A list of all LOG level names.

sub get_all_level_names {
    my @keys = sort { &NAME2LEVEL->{$a} <=> &NAME2LEVEL->{$b} } keys(%{&NAME2LEVEL});
    return(@keys);
}

# Create a logger.
# @param $inLogPath [string]
#        Path to the LOG file.
# @param %options A series of options. Options may be:
#        - level [int]
#          Log level. The value can be:
#              * &CRITICAL: Log only critical errors.
#              * &FATAL: Log fatal errors, and above (CRITICAL).
#              * &ERROR: Log simple errors, and above (FATAL, CRITICAL).
#              * &WARNING: Log warnings, and above (FATAL, CRITICAL, ERROR).
#              * &INFO: Log informational message, and above (FATAL, CRITICAL, ERROR, WARNING).
#              * &DEBUG: Log debug message, and above (FATAL, CRITICAL, ERROR, WARNING, INFO).
#              * &TRACE: Log trace message, and above (FATAL, CRITICAL, ERROR, WARNING, INFO, DEBUG).
#          Default value: &INFO
#        - session [string]
#          Session value. This value is optional.
#          Default value: a value chosen randomly.

sub new {
    my ($inClassName, $inLogPath, %options) = @_;
    my $level = exists($options{level}) ? $options{level} : &INFO;
    my $session = exists($options{session}) ? $options{session} : unique_id();

    die("Unexpected value for the LOG level ($level)") unless checkLogLevel($level);

    my $self = {
        path    => $inLogPath,
        level   => $level,
        session => $session,
        ml_tag  => 0
    };

    bless $self, $inClassName;
    return($self);
}

# Return the LOG session.
# @return [string]
#         The LOG session.

sub get_session {
    my ($self) = @_;
    return($self->{session});
}

# Set the session.
#
# @param The session to set.

sub set_session {
    my ($self, $session) = @_;
    $self->{session} = $session;
}

# LOG a critical message.
# @param $inMessage [string]
#        Message to LOG.
# @return 1: success. 0: failure.

sub critical {
    my ($self, $inMessage) = @_;
    return($self->__write(&CRITICAL, $inMessage));
}

# LOG a fatal message.
# @param $inMessage [string]
#        Message to LOG.
# @return 1: success. 0: failure.

sub fatal {
    my ($self, $inMessage) = @_;
    return($self->__write(&FATAL, $inMessage));
}

# LOG an error message.
# @param $inMessage [string]
#        Message to LOG.
# @return 1: success. 0: failure.

sub error {
    my ($self, $inMessage) = @_;
    return($self->__write(&ERROR, $inMessage));
}

# LOG a warning message.
# @param $inMessage [string]
#        Message to LOG.# @return 1: success. 0: failure.

sub warning {
    my ($self, $inMessage) = @_;
    return($self->__write(&WARNING, $inMessage));
}

# LOG an informational message.
# @param $inMessage [string]
#        Message to LOG.
# @return 1: success. 0: failure.

sub info {
    my ($self, $inMessage) = @_;
    return($self->__write(&INFO, $inMessage));
}

# LOG a debug message.
# @param $inMessage [string]
#        Message to LOG.
# @return 1: success. 0: failure.

sub debug {
    my ($self, $inMessage) = @_;
    return($self->__write(&DEBUG, $inMessage));
}

# LOG a trace.
# @param $inMessage [string]
#        Message to LOG.
# @return 1: success. 0: failure.

sub trace {
    my ($self, $inMessage) = @_;
    return($self->__write(&TRACE, $inMessage));
}

# Write a message into the LOG file.
# @param $inLevel [int]
#        LOG level.
# @param $inMessage [string]
#        Message to log.
# @return 1: success. 0: failure.

sub __write {
    my ($self, $inLevel, $inMessage) = @_;
    my $fd = undef;
    my $message = undef;
    my $path = $self->{path};
    my $level = $self->{level};

    if (($inLevel > 0) && ($inLevel > $level)) { return 0; }

    if (isMultiLine($inMessage)) {
        $message = sprintf('M(%d) ', $self->{ml_tag}) . linearize($inMessage);
    } else {
        $message = 'S ' . $inMessage;
    }

    if (! open($fd, '>>', $path)) {
        printf(STDERR "[%s:%d] Can not open my LOG file \"%s\"\n", __FILE__, __LINE__, $path);
        return(0);
    }
    print $fd now() . ' ' . $self->{session} . ' ' . &LEVEL2NAME->{$inLevel} . ' ' . $message . "\n";
    if (isMultiLine($inMessage)) {
        my $tag = sprintf('%s-%d', $self->{session}, $self->{ml_tag});
        $inMessage =~ s/^/  # ${tag} # /gm;
        print $fd "${inMessage}\n";
        $self->{ml_tag} += 1;
    }
    close $fd;
    return (1);
}

sub checkLogLevel {
    my ($inLogLevel) = @_;
    return exists(&LEVEL2NAME->{$inLogLevel});
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