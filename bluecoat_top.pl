#! /usr/bin/perl

use strict;
use warnings;
use vars qw(@ISA);
use utf8;
use POSIX;
use JSON;
use File::Temp qw(tempfile);

use Net::Nslookup;

# RUN for CROND

my $TOPLEVEL   = 25;
my $WALK       = "/usr/bin/snmpwalk";
my $AUTH_LEVEL = "authPriv";
my $USER       = "zabbix";
my $AUTH_PRT   = "SHA";
my $AUTH_PASS  = "xxxxxxxxx";
my $PRIV_PRT   = "AES";
my $PRIV_PASS  = "xxxxxxxxx";
my $TMP        = "/tmp";
my $MIB_PATH   = "/usr/share/snmp/mibs";
my $MIB        = 'TCP-MIB::tcpConnState';

my $ZBBX_SENDER   = "/usr/bin/zabbix_sender";
my $ZBBX_SERVER   = "127.0.0.1";

my %hosts;
$hosts{00001}->{hostname}   = "bcsg01.domain.com";
$hosts{00001}->{connection} = "172.16.0.3";
$hosts{00001}->{zbbx_tcp}   = "bluecoat_json_connState";
$hosts{00001}->{zbbx_top}   = "bluecoat_top";

$hosts{00002}->{hostname}   = "bcsg02.domain.com";
$hosts{00002}->{connection} = "172.16.0.4";
$hosts{00002}->{zbbx_tcp}   = "bluecoat_json_connState";
$hosts{00002}->{zbbx_top}   = "bluecoat_top";

if ( keys ( %hosts ) >= 0 ) {
  foreach my $hostid ( keys %hosts ) {
    my $hostname   = $hosts{$hostid}->{hostname};
    my $connection = $hosts{$hostid}->{connection};
    if ( ! defined $hostname or ! defined $connection ) { next; }
    if ( ! defined get_bluecoat_res ( $hostid ) ) {
      next;
      }
    if ( ! defined $hosts{$hostid}->{f_name} ) { next; }
    if ( defined $hosts{$hostid}->{zbbx_tcp} ) {
      my $zbbx_tcp = $hosts{$hostid}->{zbbx_tcp};
      if ( defined get_bluecoat_connState ( $hostid ) and defined $hosts{$hostid}->{tcpConnState} ) {
        system( "$ZBBX_SENDER -z $ZBBX_SERVER -s $hostname -k $zbbx_tcp -o \'$hosts{$hostid}->{tcpConnState}\'" );
        }
      }
    if ( defined $hosts{$hostid}->{zbbx_top} ) {
      my $zbbx_top = $hosts{$hostid}->{zbbx_top};
      if ( defined get_bluecoat_top ( $hostid ) and defined $hosts{$hostid}->{tcpTOPState} ) {
        system( "$ZBBX_SENDER -z $ZBBX_SERVER -s $hostname -k $zbbx_top -o \'$hosts{$hostid}->{tcpTOPState}\'" );
        }
      }
    }
  }
# ------------------------------------------------------------------------

sub get_bluecoat_res {
my $hostid = shift;
my $connection = $hosts{$hostid}->{connection};
my ($f_handle, $f_name) = tempfile ("bluecoat-tcpConnState-". 'XXXXXXXX', DIR => "$TMP");
system( "$WALK -v3 -l $AUTH_LEVEL -u $USER -a $AUTH_PRT -A $AUTH_PASS -x $PRIV_PRT -X $PRIV_PASS -M $MIB_PATH $connection $MIB > $f_name" );
my ( $lines_count ) = split(/\s+/, `wc -l $f_name`);
if ( $lines_count < 100 ) {
  print "error snmp request broken\n";
  unlink( $f_name ) or die "Can't delete $f_name $!\n";
  return undef;
  }
$hosts{$hostid}->{f_name} = $f_name;
return 1;
}
# ------------------------------------------------------------------------

sub get_bluecoat_connState {
my $hostid = shift;

my %tcpConnState;
$tcpConnState{tcpState}{closed}=0;
$tcpConnState{tcpState}{listen}=0;
$tcpConnState{tcpState}{synSent}=0;
$tcpConnState{tcpState}{synReceived}=0;
$tcpConnState{tcpState}{established}=0;
$tcpConnState{tcpState}{finWait1}=0;
$tcpConnState{tcpState}{finWait2}=0;
$tcpConnState{tcpState}{closeWait}=0;
$tcpConnState{tcpState}{lastAck}=0;
$tcpConnState{tcpState}{closing}=0;
$tcpConnState{tcpState}{timeWait}=0;
$tcpConnState{tcpState}{deleteTCB}=0;
if ( defined $hosts{$hostid}->{f_name} and -e $hosts{$hostid}->{f_name} ) {
  open (REQ, $hosts{$hostid}->{f_name} ) or die SaveLog("Can't open $hosts{$hostid}->{f_name}");
  while (<REQ>) {
    chomp($_);
    my ( $ip, $a , $b ,$tcpConnState ) = split (" ", lc($_));
    # TCP-MIB::tcpConnState.172.16.хх.хх.8080.10.0.0.хх.62719 = INTEGER: established(5)
    # TCP-MIB::tcpConnState.172.16.хх.хх.8080.10.6.1.хх.51991 = INTEGER: established(5)
    # TCP-MIB::tcpConnState.172.16.хх.хх.8080.10.6.1.хх.53173 = INTEGER: finWait1(6)
    # $ip            TCP-MIB::tcpConnState.172.16.хх.хх.8080.10.0.0.хх.62719
    # $a             =
    # $b             integer:
    # $tcpConnState  established(5)
    if ( defined $tcpConnState ) {
      if    ( $tcpConnState eq "closed(1)" )      { $tcpConnState{tcpState}{closed}++;      }
      elsif ( $tcpConnState eq "listen(2)" )      { $tcpConnState{tcpState}{listen}++;      }
      elsif ( $tcpConnState eq "synsent(3)" )     { $tcpConnState{tcpState}{synSent}++;     }
      elsif ( $tcpConnState eq "synreceived(4)" ) { $tcpConnState{tcpState}{synReceived}++; }
      elsif ( $tcpConnState eq "established(5)" ) { $tcpConnState{tcpState}{established}++; }
      elsif ( $tcpConnState eq "finwait1(6)" )    { $tcpConnState{tcpState}{finWait1}++;    }
      elsif ( $tcpConnState eq "finwait2(7)" )    { $tcpConnState{tcpState}{finWait2}++;    }
      elsif ( $tcpConnState eq "closewait(8)" )   { $tcpConnState{tcpState}{closeWait}++;   }
      elsif ( $tcpConnState eq "lastack(9)" )     { $tcpConnState{tcpState}{lastAck}++;     }
      elsif ( $tcpConnState eq "closing(10)" )    { $tcpConnState{tcpState}{closing}++;     }
      elsif ( $tcpConnState eq "timewait(11)" )   { $tcpConnState{tcpState}{timeWait}++;    }
      elsif ( $tcpConnState eq "deletetcb(12)" )  { $tcpConnState{tcpState}{deleteTCB}++;   }
      }
    }
  }
my $tcpConnState;
if ( defined $tcpConnState{tcpState} and scalar ( keys ( $tcpConnState{tcpState} ) ) >= 0 ) {
  $tcpConnState = encode_json \%tcpConnState;
  }
if ( ! defined $tcpConnState ) {
  return undef;
  }
$hosts{$hostid}->{tcpConnState} = $tcpConnState;
return 1;
}
# ------------------------------------------------------------------------

sub get_bluecoat_top {
my $hostid = shift;

my %tcpTOPState;
my $tcpTOPState1;

if ( defined $hosts{$hostid}->{f_name} and -e $hosts{$hostid}->{f_name} ) {
  open (REQ, "$hosts{$hostid}->{f_name}") or die SaveLog("Can't open $hosts{$hostid}->{f_name}");
  while (<REQ>) {
    chomp($_);
    my ( $ip, $a , $b ,$tcpConnState ) = split (" ", lc($_));
    my $ip1;
    my $ip1_type = "remote";
    my $ip2;
    my $ip2_type = "remote";
    if ( $ip =~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(\.\d{1,}\.)(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(\.\d{1,})/ ) {
      $ip1 = $1;
      $ip2 = $3;
      }
    if ( defined $ip1 and defined $ip2 ) {
      if ( $ip1 =~ /172\.(16|17|18|19|20|21|22|23|24|25|26|30)\.\d{1,3}\.\d{1,3}/ or $ip1 =~ /10\.\d{1,3}\.\d{1,3}\.\d{1,3}/ or  $ip1 =~ /192\.168\.\d{1,3}\.\d{1,3}/ ) {
        $ip1_type = "local";
        }
      if ( $ip1 =~ /172\.(16|17|18|19|20|21|22|23|24|25|26|30)\.\d{1,3}\.\d{1,3}/ or $ip1 =~ /10\.\d{1,3}\.\d{1,3}\.\d{1,3}/ or $ip1 =~ /192\.168\.\d{1,3}\.\d{1,3}/ ) {
        $ip2_type = "local";
        }
      }
    if ( defined $ip1_type and defined $ip2_type ) {
      if    ( $ip1_type eq "local" and $ip2_type eq "local" ) {
        $tcpTOPState{local}{$ip2}++;
        }
      elsif ( $ip1_type eq "local" and $ip2_type eq "remote" ) {
        $tcpTOPState{remote}{$ip2}++;
        }
      else {
        $tcpTOPState{remote}{$ip2}++;
        }
      }
    }
  }
my $i;
if ( defined $tcpTOPState{remote} and scalar ( keys ( $tcpTOPState{remote} ) ) >= 0 ) {
  $tcpTOPState1 = " Remote connect\n";
  $i=1;
  for my $host ( reverse sort { $tcpTOPState{remote}{$a} <=> $tcpTOPState{remote}{$b} } keys $tcpTOPState{remote} ) {
    if ( $i <= $TOPLEVEL ) {
      my $value = $tcpTOPState{remote}{$host};
      my $DNSnslookup = nslookup (host => $host, type => "PTR");
      if ( defined $DNSnslookup ) {
        $tcpTOPState1 .= "  [ ".sprintf("%03d",$value)." ] $DNSnslookup $host\n";
        }
      else {
        $tcpTOPState1 .= "  [ ".sprintf("%03d",$value)." ] $host\n";
        }
      }
    $i++;
    }
  }
if ( defined $tcpTOPState{local} and scalar ( keys ( $tcpTOPState{local} ) ) >= 0 ) {
  $tcpTOPState1 .= " Local connect\n";
  $i=1;
  for my $host ( reverse sort { $tcpTOPState{local}{$a} <=> $tcpTOPState{local}{$b} } keys $tcpTOPState{local} ) {
    if ( $i <= $TOPLEVEL ) {
      my $value = $tcpTOPState{local}{$host};
      my $DNSnslookup = nslookup (host => $host, type => "PTR");
      if ( defined $DNSnslookup ) {
        $tcpTOPState1 .= "  [ ".sprintf("%03d",$value)." ] $DNSnslookup $host\n";
        }
      else {
        $tcpTOPState1 .= "  [ ".sprintf("%03d",$value)." ] $host\n";
        }
      }
    $i++;
    }
  }
if ( ! defined $tcpTOPState1 ) {
  return undef;
  }
$hosts{$hostid}->{tcpTOPState} = $tcpTOPState1;
return 1;
}
# ------------------------------------------------------------------------
