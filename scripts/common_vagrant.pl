#!/usr/bin/perl
#
# init_vagrant() will be run on BOTH the host machine and the Vagrant VM. So
# it should NOT require any non-standard Perl modules.

use Encode;

$VAGRANT = 1; # Vagrant is on by default. To run natively, add "$Vagrant=0;" to paths.pl

$HOME_DIR = `echo \$HOME`; chomp($HOME_DIR);

sub init_vagrant() {
  if (!$INPD) {$INPD = "."};
  $INPD =~ s/[\\\/]\s*$//;
  if ($INPD =~ /^\./) {$INPD = File::Spec->rel2abs($INPD);}
  $INPD =~ s/[\\\/](sfm|GoBible|eBook)$//; # allow using a subdir as project dir
  if (!-e $INPD) {
    print "ERROR: Project directory \"$INPD\" does not exist. Exiting...\n";
    exit;
  }
  chdir($INPD);
  
  if (-e "$SCRD/paths.pl") {require "$SCRD/paths.pl";}
  
  # Return and continue this process if it is being run on the VM
  if (&runningVagrant()) {return;}
  
  # Return and continue this host process for a 40% speedup, if all dependencies for this script are installed
  if ($VAGRANT==0) {
    if (&haveDependencies($SCRIPT, $SCRD, $INPD, 1)) {
      print "
  NOTE: You are running osis-converters without vagrant because \$VAGRANT=0 
        and proper dependencies have been installed on the host for running:
        $SCRIPT\n\n";
      return;
    }
  }
  
  # Otherwise start a new process on the VM and exit this current host process
  if (&vagrantInstalled()) {startVagrant($SCRD, $SCRIPT, $INPD);}
  else {print "ERROR: Vagrant is not installed and cannot continue on host. Exiting...\n";}
  
  exit;
}

sub vagrantInstalled() {
  print "\n";
  my $pass;
  system("vagrant -v >tmp.txt 2>&1");
  if (!open(TEST, "<tmp.txt")) {die;}
  $pass = 0; while (<TEST>) {if ($_ =~ /\Qvagrant\E/i) {$pass = 1; last;}}
  if (!$pass) {
    print "
ERROR: The shell command \"vagrant -v\" did not return \"vagrant\" 
so Vagrant may not be installed.

osis-converters requires:
Vagrant (from https://www.vagrantup.com/downloads.html)
Virtualbox (from https://www.virtualbox.org/wiki/Downloads)\n";
  }
  print "\n";
  unlink("tmp.txt");

  return $pass;
}

sub startVagrant($$$) {
  my $scrd = shift;
  my $script = shift;
  my $inpd = shift;
  my @args = ("$scrd/Vagrant.pl", $script, $inpd);
  print "@args\n";
  system(@args); # exec does not run with Windows cmd shell
  exit;
}

# Return 1 if dependencies are met for $script and 0 if not
sub haveDependencies($$$$) {
  my $script = shift;
  my $scrd = shift;
  my $inpd = shift;
  my $quiet = shift;
  
  my $logflag = ($quiet ? ($DEBUG ? 2:3):1);

  my @deps;
  if ($script =~ /(sfm2all)/) {
    @deps = ('SWORD_PERL', 'SWORD_BIN', 'XMLLINT', 'GO_BIBLE_CREATOR', 'MODULETOOLS_BIN', 'XSLT2', 'CALIBRE');
  }
  elsif ($script =~ /(sfm2osis|osis2osis)/) {
    @deps = ('SWORD_PERL', 'XMLLINT', 'MODULETOOLS_BIN', 'XSLT2');
  }
  elsif ($script =~ /osis2sword/) {
    @deps = ('SWORD_PERL', 'SWORD_BIN', 'MODULETOOLS_BIN', 'XSLT2');
  }
  elsif ($script =~ /osis2ebooks/) {
    @deps = ('SWORD_PERL', 'MODULETOOLS_BIN', 'XSLT2', 'CALIBRE');
  }
  elsif ($script =~ /osis2html/) {
    @deps = ('SWORD_PERL', 'MODULETOOLS_BIN', 'XSLT2');
  }
  elsif ($script =~ /osis2GoBible/) {
    @deps = ('SWORD_PERL', 'GO_BIBLE_CREATOR', 'MODULETOOLS_BIN', 'XSLT2');
  }
  
  # XSLT2 also requires that openjdk 10.0.1 is NOT being used 
  # because its Unicode character classes fail with saxonb-xslt.
  my %depsh = map { $_ => 1 } @deps;
  if ($depsh{'XSLT2'}) {push(@deps, 'JAVA');}
  
  # All paths must end in / or else be empty. 
  # Paths which are empty must refer to executables in the shell's path
  foreach my $p (@deps) {
    if (&runningVagrant() && $$p) {
      if ($p eq 'MODULETOOLS_BIN') {
        &Log("NOTE: Using network share to \$$p in paths.pl while running in Vagrant.\n", $logflag);
      }
      else {
        &Log("WARNING: Ignoring \$$p in paths.pl while running in Vagrant.\n", $logflag);
      }
      $$p = '';
    }
    if ($p eq 'GO_BIBLE_CREATOR' && !$$p) {$$p = "$HOME_DIR/.osis-converters/GoBibleCreator.245";} # Default location
    if ($p eq 'MODULETOOLS_BIN' && !$$p) {$$p = "$HOME_DIR/.osis-converters/src/Module-tools/bin";} # Default location
    if ($$p) {
      if ($p =~ /^\./) {$$p = File::Spec->rel2abs($$p);}
      $$p =~ s/[\\\/]+\s*$//;
      $$p .= "/";
    }
  }
  
  my %test;
  $test{'SWORD_BIN'}        = [ &escfile($SWORD_BIN."osis2mod"), "You are running osis2mod: \$Rev: 3322 \$" ]; # want specific version
  $test{'XMLLINT'}          = [ &escfile($XMLLINT."xmllint")." --version", "xmllint: using libxml" ]; # who cares what version
  $test{'GO_BIBLE_CREATOR'} = [ "java -jar ".&escfile($GO_BIBLE_CREATOR."GoBibleCreator.jar"), "Usage" ];
  $test{'MODULETOOLS_BIN'}  = [ &escfile($MODULETOOLS_BIN."usfm2osis.py"), "Revision: 491" ]; # check version
  $test{'XSLT2'}            = [ 'saxonb-xslt', "Saxon 9" ]; # check major version
  $test{'JAVA'}             = [ 'java -version', "openjdk version \"10.0.1\"", 1 ]; # NOT openjdk 10.0.1
  $test{'CALIBRE'}          = [ "ebook-convert --version", "calibre 3.2" ]; # check major version
  $test{'SWORD_PERL'}       = [ "perl -le 'use Sword; print \$Sword::SWORD_VERSION_STR'", "1.7.3" ]; # check version
  
  my $failMes = '';
  foreach my $p (@deps) {
    if (!exists($test{$p})) {
      &Log("ERROR checkDependencies: No test for $p!\n");
      return 0;
    }
    system($test{$p}[0]." >".&escfile("tmp.txt"). " 2>&1");
    if (!open(TEST, "<tmp.txt")) {
      &Log("ERROR: could not read test output \"$SCRD/tmp.txt\"!\n");
      return 0;
    }
    my $result; {local $/; $result = <TEST>;} close(TEST); unlink("tmp.txt");
    my $need = $test{$p}[1];
    if (!$test{$p}[2] && $result !~ /\Q$need\E/im) {
      $failMes .= "\nERROR: Dependency $p failed:\n\tRan: \"".$test{$p}[0]."\"\n\tLooking for: \"$need\"\n\tGot:\n$result\n";
    }
    elsif ($test{$p}[2] && $result =~ /\Q$need\E/im) {
      $failMes .= "\nERROR: Dependency $p failed:\n\tRan: \"".$test{$p}[0]."\"\n\tCannot have: \"$need\"\n\tGot:\n$result\n";
    }
    #&Log("NOTE:  Dependency $p:\n\tRan: \"".$test{$p}[0]."\"\n\tGot:\n$result\n");
  }
  
  if ($failMes) {
    &Log("\n$failMes\n", $logflag);
    if (!&runningVagrant()) {
      &Log("
NOTE: On Linux systems you can try installing dependencies by running:
      $scrd/VagrantProvision.sh\n\n", 1);
    }
    return 0;
  }
  
  $MODULETOOLS_GITHEAD = `cd "$MODULETOOLS_BIN" && git rev-parse HEAD 2>tmp.txt`; unlink("tmp.txt");
  &Log("Module-tools git rev: $MODULETOOLS_GITHEAD", $logflag);
  
  &Log("Using ".`calibre --version`."\n", $logflag);
  
  return 1;
}

sub runningVagrant() {return (-e "/vagrant/Vagrant.pl" ? 1:0);}

sub escfile($) {
  my $n = shift;
  
  $n =~ s/([ \(\)])/\\$1/g;
  return $n;
}

# Log to console and logfile. $flag can have these values:
# -1 = only log file
#  0 = log file (+ console unless $NOCONSOLELOG is set)
#  1 = log file + console (ignoring $NOCONSOLELOG)
#  2 = only console
#  3 = don't log anything
sub Log($$) {
  my $p = shift; # log message
  my $flag = shift;
  
  if ($flag == 3) {return;}
  
  $p =~ s/&#(\d+);/my $r = chr($1);/eg;
  
  if ((!$NOCONSOLELOG && $flag != -1) || $flag >= 1 || $p =~ /ERROR/) {
    print encode("utf8", $p);
  }
  
  if ($flag == 2) {return;}
  
  $p = &encodePrintPaths($p);
  
  if (!$LOGFILE) {$LogfileBuffer .= $p; return;}

  open(LOGF, ">>:encoding(UTF-8)", $LOGFILE) || die "Could not open log file \"$LOGFILE\"\n";
  if ($LogfileBuffer) {print LOGF $LogfileBuffer; $LogfileBuffer = '';}
  print LOGF $p;
  close(LOGF);
}

sub encodePrintPaths($) {
  my $t = shift;
  
  # encode these local file paths
  my @paths = ('INPD', 'OUTDIR', 'SWORD_BIN', 'XMLLINT', 'MODULETOOLS_BIN', 'XSLT2', 'GO_BIBLE_CREATOR', 'CALIBRE', 'SCRD');
  foreach my $path (@paths) {
    if (!$$path) {next;}
    my $rp = $$path;
    $rp =~ s/[\/\\]+$//;
    $t =~ s/\Q$rp\E/\$$path/g;
  }
  return $t;
}

1;
