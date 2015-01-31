package umod;

use strict;
use warnings;

sub new {
  my $class = shift;
  my $self = {};

  bless($self, $class);
 
}

sub load {
  my $self = shift;
  my $file = shift;

  open($self->{'fh'}, "<", $file) or die "Can't open $file: $!";
  $self->getHeaders();
  $self->getDirectory();
}

sub getHeaders {
  my $self = shift;

  seek($self->{'fh'}, -20, 2);
  $self->{'header'}->{'magick_number'} = $self->readDWord();
  $self->{'header'}->{'offset'} = $self->readDWord();
  $self->{'header'}->{'size'} = $self->readDWord();
  $self->{'header'}->{'version'} = $self->readDWord();
  $self->{'header'}->{'checksum'} = $self->readDWord();
}

sub getDirectory {
  my $self = shift;

  my @directory;

  seek($self->{'fh'}, $self->{'header'}->{'offset'}, 0);
  my $num_files = $self->readIndex();
    
  foreach (1 .. $num_files) {
    # don't need num_characters as this is determined in readString();
    my $filename = $self->readString();
    my $offset = $self->readDWord();
    my $length = $self->readDWord();
    my $flags = $self->readDWord();

    push(@directory, {filename => $filename, offset => $offset, length => $length, flags => $flags});
  }
  $self->{'directory'} = \@directory;
}

sub getFile {
  my $self = shift;
  my $offset = shift;
  my $length = shift;
  
  my $string;
  seek($self->{'fh'}, $offset, 0);
  read($self->{'fh'}, $string, $length);
  
  return $string;  
}

sub readDWord {
  my $self = shift;
  my $string;
  my $char = read($self->{'fh'}, $string, 4);
  my $long = unpack("l", $string);
    
  return $long;
}

sub readIndex {
  my $self = shift;
 
  my $buffer;
  my $neg;
  my $length = 6;
  my $start = tell($self->{'fh'});

  for(my $i = 0; $i < 5; $i++) {
    my $more = 0;
    my $char;
    read($self->{'fh'}, $char, 1);
    $char = vec($char, 0, 8);

    if ($i == 0) {
      $neg = ($char & 0x80);
      $more = ($char & 0x40);
      $buffer = ($char & 0x3F);
    }
    elsif ($i == 4) {
      $buffer |= ($char & 0x80) << $length;
      $more = 0;
    }
    else {
     $more = ($char & 0x80);
     $buffer |= ($char & 0x7F) << $length;
     $length += 7;
    }
    last unless ($more);
  }

  if ($neg) {
    $buffer *= -1;
  }
  
  return $buffer;
}

sub readString {
  my $self = shift;
  
  my $string;
  my $char = 1;
  
  my $start = tell($self->{'fh'});
  
  my $size = $self->readIndex();
  if ($size <= 0) {
    warn("0 or negative length on readstring at " . tell($self->{'fh'}));
    $self->{'debuglog'} .= "0 or negative length on readstring at " . tell($self->{'fh'}) . "\n";
    # fall back to the old system
    $char = 1;
    while (ord($char) != 0) {
      read($self->{'fh'}, $char, 1);
      $string .= $char;
    }
  }
  else {
    read($self->{'fh'}, $string, $size);
  }

  # remove the last zerobyte character
  chop($string);
  
  $self->{'debuglog'} .= "<- Read string at " . $start . ": " . $string . "\n";
  
  return $string; 
}

1;
