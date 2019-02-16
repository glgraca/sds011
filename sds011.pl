#!/usr/bin/perl
use Device::SerialPort qw(:PARAM :STAT 0.07);
use Data::Dumper;
use strict;
use warnings;

#Autoflush
$|++;

sub build_cmd {
  my $cmd=shift;
  my @data=@_;
  my $checksum=0;

  #Push zeroes until we have 12 items
  push @data, 0 while scalar(@data)<12;

  #Calculate checksum as sum(@data)%256
  $checksum+=$_ for @data;
  $checksum=($checksum+$cmd-2)%256;

  #Build command struct
  $cmd=pack('C*',0xAA,0xB4,$cmd,@data,0xFF,0xFF,$checksum,0xAB);
  return $cmd;
}

sub read_response {
  my $port=shift;
  my $byte=0;
  my $count=0;
  my $buffer;

  #Search for header
  while(length($byte)==0 || $byte != 0xAA) {
    ($count, $byte)=$port->read(1);
    $byte=unpack('C', $byte) if $count;
  }

  #Read body
  ($count, $buffer)=$port->read(9);

  return $buffer;
}

sub chat {
  my $port=shift;
  my $count=$port->write(build_cmd(@_));
  my $response=read_response($port);
  return $response;
}

my $device='/dev/ttyUSB0';
my $port=new Device::SerialPort($device, 1)
  || die "Cannot open $device: $!\n";

$port->baudrate(9600);
$port->write_settings();

#Wake up
chat($port,6,1,1);
print "Woke up\n";

#Enter query mode
chat($port,2,1,1);
print "Entered query mode \n";


sleep(10);

#Query data
my $response=chat($port,4);
my ($command, $pm25, $pm10, $id, $checksum, $tail)=unpack('CSSSCC',$response);
$pm25/=10.0;
$pm10/=10.0;
print "PM25:\t$pm25\tPM10:\t$pm10\n";

#Exit query mode
chat($port,2,1,0);
print "Left query mode\n";

#Sleep
chat($port,6,1,0);
print "Went to sleep\n";

END {
  $port->close();
}
