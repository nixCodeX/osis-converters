#!/usr/bin/perl
# This file is part of "osis-converters".
# 
# Copyright 2012 John Austin (gpl.programs.info@gmail.com)
#     
# "osis-converters" is free software: you can redistribute it and/or 
# modify it under the terms of the GNU General Public License as 
# published by the Free Software Foundation, either version 2 of 
# the License, or (at your option) any later version.
# 
# "osis-converters" is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with "osis-converters".  If not, see 
# <http://www.gnu.org/licenses/>.

# usage: osis2sword.pl [Project_Directory]

# Run this script to create raw and zipped SWORD modules from an 
# osis.xml file and a config.conf file located in the Project_Directory.

# OSIS wiki: http://www.crosswire.org/wiki/OSIS_Bibles
# CONF wiki: http://www.crosswire.org/wiki/DevTools:conf_Files

$INPD = shift; $LOGFILE = shift;
use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){1}$//;
require "$SCRD/scripts/common_vagrant.pl"; &init_vagrant();
require "$SCRD/scripts/common.pl"; &init();

require "$SCRD/scripts/dict/processGlossary.pl";

&runAnyUserScriptsAt("sword/preprocess", \$INOSIS);

&forwardGlossLinks(\$INOSIS);

if ($MODDRV =~ /LD/) {&removeDuplicateEntries(\$INOSIS);}

my $typePreProcess = ($MODDRV =~ /Text/ ? 'osis2sword.xsl':($MODDRV =~ /LD/ ? 'osis2tei.xsl':''));
if ($typePreProcess) {&runScript($MODULETOOLS_BIN.$typePreProcess, \$INOSIS);}

if ($UPPERCASE_DICTIONARY_KEYS) {&upperCaseKeys(\$INOSIS);}

if (&copyReferencedImages($INOSIS, $INPD, "$SWOUT/$MODPATH")) {
  $ConfEntryP->{'Feature'} = ($ConfEntryP->{'Feature'} ? $ConfEntryP->{'Feature'}."<nx/>":"")."Images";
}

if ($ConfEntryP->{"Font"} && $FONTS) {
  &copyFont($ConfEntryP->{"Font"}, $FONTS, \%FONT_FILES, "$SWOUT/fonts", 0);
}

$msv = "1.6.1";
if ($VERSESYS && $VERSESYS ne "KJV") {
  system(&escfile($SWORD_BIN."osis2mod")." 2> ".&escfile("$TMPDIR/osis2mod_vers.txt"));
  open(OUTF, "<:encoding(UTF-8)", "$TMPDIR/osis2mod_vers.txt") || die "Could not open $TMPDIR/osis2mod_vers.txt\n";
  while(<OUTF>) {
    if ($_ =~ (/\$rev:\s*(\d+)\s*\$/i) && $1 > 2478) {
      $msv = "1.6.2"; last;
    }
  }
  close(OUTF);
  unlink("$TMPDIR/osis2mod_vers.txt");
  if ($VERSESYS eq "SynodalProt") {$msv = "1.7.0";}
  $ConfEntryP->{'MinimumVersion'} = $msv;
}

if ($MODDRV =~ /Text/) {
	$ConfEntryP->{'Category'} = 'Biblical Texts';
  
  if ($MODDRV =~ /zText/) {
    $ConfEntryP->{'CompressType'} = 'ZIP';
    $ConfEntryP->{'BlockType'} = 'BOOK';
  }

  &writeConf("$SWOUT/mods.d/$MODLC.conf", $ConfEntryP, $CONFFILE, $INOSIS);
  &Log("\n--- CREATING $MOD SWORD MODULE (".$VERSESYS.")\n");
  $cmd = &escfile($SWORD_BIN."osis2mod")." ".&escfile("$SWOUT/$MODPATH")." ".&escfile($INOSIS)." ".($MODDRV =~ /zText/ ? ' -z z':'').($VERSESYS ? " -v $VERSESYS":'').($MODDRV =~ /Text4/ ? ' -s 4':'')." >> ".&escfile($LOGFILE);
  &Log("$cmd\n", -1);
  system($cmd);
  
  &emptyvss($SWOUT);
}
elsif ($MODDRV =~ /^RawGenBook$/) {
  &writeConf("$SWOUT/mods.d/$MODLC.conf", $ConfEntryP, $CONFFILE, $INOSIS);
	&Log("\n--- CREATING $MOD RawGenBook SWORD MODULE (".$VERSESYS.")\n");
	$cmd = &escfile($SWORD_BIN."xml2gbs")." $INOSIS $MODLC >> ".&escfile($LOGFILE);
	&Log("$cmd\n", -1);
	chdir("$SWOUT/$MODPATH");
	system($cmd);
	chdir($SCRD);
}
elsif ($MODDRV =~ /LD/) {
  &writeConf("$SWOUT/mods.d/$MODLC.conf", $ConfEntryP, $CONFFILE, $INOSIS);
  &Log("\n--- CREATING $MOD Dictionary TEI SWORD MODULE (".$VERSESYS.")\n");
  $cmd = &escfile($SWORD_BIN."tei2mod")." ".&escfile("$SWOUT/$MODPATH")." ".&escfile($INOSIS)." -s ".($MODDRV eq "RawLD" ? "2":"4")." >> ".&escfile($LOGFILE);
  &Log("$cmd\n", -1);
  system($cmd);
  # tei2mod creates module files called "dict" which are non-standard, so fix
  opendir(MODF, "$SWOUT/$MODPATH");
  my @mf = readdir(MODF);
  closedir(MODF);
  foreach my $m (@mf) {
  if ($m !~ /^dict\.(.*?)$/) {next;}
    rename("$SWOUT/$MODPATH/$m", "$SWOUT/$MODPATH/$MODLC.$1");
  }
}
else {
	&Log("ERROR: Unhandled module type \"$MODDRV\".\n");
	die;
}
$CONFFILE = "$SWOUT/mods.d/$MODLC.conf";
if ($ConfEntryP->{"PreferredCSSXHTML"} && ! -e "$INPD/sword/css/".$ConfEntryP->{"PreferredCSSXHTML"}) {
  &Log("ERROR: The conf file specifies PreferredCSSXHTML but it was not found at \"$INPD/sword/css/".$ConfEntryP->{"PreferredCSSXHTML"}."\".\n");
}
elsif (-e "$INPD/sword/css") {
  if ($ConfEntryP->{"PreferredCSSXHTML"}) {
    copy("$INPD/sword/css/".$ConfEntryP->{"PreferredCSSXHTML"}, "$SWOUT/$MODPATH");
    &Log("\n--- COPYING PreferredCSSXHTML \"$INPD/sword/css/".$ConfEntryP->{"PreferredCSSXHTML"}."\"\n");
  }
  else {&Log("ERROR: \"$INPD/sword/css\" directory exists, but conf file lacks a PreferredCSSXHTML entry.\n");}
}

&writeInstallSizeToConf($CONFFILE, "$SWOUT/$MODPATH");

&zipModule($OUTZIP, $SWOUT);

&Log("\n\nFINAL CONF FILE CONTENTS:\n", 1);
open(CONF, "<:encoding(UTF-8)", $CONFFILE) || die "Could not open $CONFFILE\n";
while(<CONF>) {&Log("$_", 1);}
close(CONF);

&Log("\nend time: ".localtime()."\n");

1;
