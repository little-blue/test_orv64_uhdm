#------------------------------------------------------
# Module Name: CDC
# Date:        Mon Sep 21 12:34:53 2020
# Author:      kvu
# Type:        cdc
#------------------------------------------------------
package Hydra::Setup::Flow::CDC;

use strict;
use warnings;
use Carp;
use Exporter;

our $VERSION = 1.00;
our @ISA     = qw(Exporter);

#------------------------------------------------------
# Global Variables
#------------------------------------------------------

#------------------------------------------------------
# Subroutines
#------------------------------------------------------

#++
# Tool: spyglass
# Flow: CDC
#--
sub spyglass_CDC {
  my ($Paramref) = @_;
  my $design_name = $Paramref->get_param_value("GLOBAL_design", "strict");

  my @LibFiles = &Hydra::Setup::Flow::HYDRA::INIT_LIBRARY($Paramref, "cdc");
  
  # Run scripts
  my $KickoffFile = new Hydra::Setup::File("HYDRA.run", "cdc");
  #&Hydra::Setup::Flow::write_std_kickoff($Paramref, $KickoffFile, ("script/cdc.tcl"));
  my $time = localtime;
  $KickoffFile->add_line("#!/usr/bin/bash");
  $KickoffFile->add_line("# Generated by Hydra on $time");
  $KickoffFile->add_line("export HYDRA_HOME=$ENV{HYDRA_HOME}");
  $KickoffFile->add_line("export SKIP_PLATFORM_CHECK=1");

  # This might be dangerous
  my $dc_home = &Hydra::Setup::Tool::get_tool_binary($Paramref, "synth");
  $dc_home =~ s/\/bin\/dc_shell$//;
  $KickoffFile->add_line("export SPYGLASS_DC_PATH=${dc_home}");

  # This might also be dangerous
  my $spy_home = &Hydra::Setup::Tool::get_tool_binary($Paramref, "cdc");
  $spy_home =~ s/\/bin\/sg_shell$//;
  $KickoffFile->add_line("export SPYGLASS_HOME=${spy_home}");
  $KickoffFile->add_linebreak;

  # Check spyglass home for UFE version of vc shell
  if (!-f "${spy_home}/lib/multi-vcst/bin/vc_static_shell") {
    print "WARN: Non-UFE SpyGlass detected while generating CDC which uses VCS compile\n";
    print "      Change binary in HYDRA_cdc_bin to one with UFE\n";
  }

  my $rtl_flist = $Paramref->get_param_value("CDC_rtl_flist", "strict");
  my @flists = split(/\s+/, &Hydra::Setup::Param::remove_param_value_linebreak($rtl_flist));
  my $flist_string = join(" ", map { "\"${_}\"" } @flists);
  $KickoffFile->add_line("\${HYDRA_HOME}/hydra.pl report_git_info -rtl_flist $flist_string -out_file ./rpt/rtl_files.list");
  $KickoffFile->add_linebreak;

  my $tool_command = &Hydra::Setup::Tool::get_tool_command($Paramref, $KickoffFile->get_type, "script/cdc.tcl");
  $KickoffFile->add_line($tool_command);
  $KickoffFile->make_executable;

  my @ScriptFiles = ();
  my $line = "";
  my $sgdc = $Paramref->get_param_value("CDC_sgdc", "relaxed");

  if (!&Hydra::Setup::Param::has_value($sgdc)) {
    $sgdc = "./script/cdc.sgdc";

    # Sgdc file
    my $SGDCFile = new Hydra::Setup::File("script/cdc.sgdc", "cdc");
    $line = "";

    my $sdc = &Hydra::Util::File::resolve_env($Paramref->get_param_value("CDC_sdc", "strict"));
    $line .= sprintf <<EOF;
current_design $design_name

sdc_data -file $sdc
EOF

    $SGDCFile->add_line($line);
    push(@ScriptFiles, $SGDCFile);
  }
  
  # Tool scripts
  my $ScriptFile = new Hydra::Setup::File("script/cdc.tcl", "cdc");
  $line = "";

  $line .= sprintf <<EOF;
source script/cdc_init_library.tcl
source $ENV{HYDRA_HOME}/script/tcl/file_to_list.tcl

new_project ./db/${design_name}.prj -projectwdir "./db" -force

set_option auto_save yes
set_option enable_gateslib_autocompile yes
set_option enable_sglib_debug yes
set_option dw yes
set_option mthresh 65535
set_option include_opt_data true
set_option use_vcs_compile yes
set_option libhdl_extmap .v verilog2005
set_option hdllibdu yes
set_option disable_amg yes
set_option report_ip_waiver yes

EOF

  my @incdirs = ();
  my $has_v   = 0;
  my $resolved_rtl_flist = &Hydra::Util::File::resolve_env($rtl_flist);
  if (-f $resolved_rtl_flist) {
    my ($aref_files, $aref_incdirs, $flist_has_v) = &Hydra::Util::File::expand_file_list($resolved_rtl_flist);
    $has_v = $flist_has_v;
    @incdirs = @$aref_incdirs;
  }

  if ($has_v) {
    # Allow module override if -v option is used in flist
    $line .= "# Allow module redeclaration for netlist run\n";
    $line .= "set_option allow_module_override yes\n";
    $line .= "\n";
  }

  $line .= "# Read RTL\n";
  foreach my $flist (@flists) {
    $line .= "read_file -type hdl [concat [expand_file_list \"${flist}\"]]\n"
  }

  my $lib_var = &Hydra::Setup::Flow::get_scenario_lib_var($Paramref, "CDC", "lib");
  $line .= sprintf <<EOF;
read_file -type gateslib [concat \"\$$lib_var\"]
read_file -type sgdc $sgdc

EOF

  if (scalar(@incdirs) > 0) {
    my $dir_list = "\"" . join(" ", @incdirs) . "\"";
    $line .= "set_option incdir $dir_list\n";
  }

  my $define = $Paramref->get_param_value("CDC_define", "relaxed");
  $line .= &Hydra::Setup::Flow::write_repeating_param("set_option define", $define);
  $line .= "\n";

  $line .= sprintf <<EOF;

set_option enableSV09 yes
set_option top ${design_name}
current_methodology \$SPYGLASS_HOME/GuideWare/latest/block/initial_rtl

EOF

  $line .= &Hydra::Setup::Flow::write_source_catchall($Paramref, "CDC");

  $line .= sprintf <<EOF;

current_goal cdc/cdc_verify_struct
run_goal

save_project

write_aggregate_report project_summary -reportdir "./rpt"

exit

EOF

  $ScriptFile->add_line($line);
  push(@ScriptFiles, $ScriptFile);

  return (@LibFiles, @ScriptFiles, $KickoffFile);


}

#++
# Tool: conformal_ec
# Flow: CDC
#--
sub conformal_ec_CDC {
  my ($Paramref) = @_;
  my $design_name = $Paramref->get_param_value("GLOBAL_design", "strict");

  my @LibFiles = &Hydra::Setup::Flow::HYDRA::INIT_LIBRARY($Paramref, "cdc");

  # Run scripts
  my $KickoffFile = new Hydra::Setup::File("HYDRA.run", "cdc");
  #&Hydra::Setup::Flow::write_std_kickoff($Paramref, $KickoffFile, ("script/cdc.tcl"));
  my $time = localtime;
  $KickoffFile->add_line("#!/usr/bin/bash");
  $KickoffFile->add_line("# Generated by Hydra on $time");
  $KickoffFile->add_line("export HYDRA_HOME=$ENV{HYDRA_HOME}");
  $KickoffFile->add_linebreak;
  
  my $rtl_flist = $Paramref->get_param_value("CDC_rtl_flist", "strict");
  my @flists = split(/\s+/, &Hydra::Setup::Param::remove_param_value_linebreak($rtl_flist));
  my $flist_string = join(" ", map { "\"${_}\"" } @flists);
  $KickoffFile->add_line("\${HYDRA_HOME}/hydra.pl report_git_info -rtl_flist $flist_string -out_file ./rpt/rtl_files.list");
  $KickoffFile->add_linebreak;

  my $tool_command = &Hydra::Setup::Tool::get_tool_command($Paramref, $KickoffFile->get_type, "script/cdc.tcl");
  $KickoffFile->add_line($tool_command);
  $KickoffFile->make_executable;

  my @ScriptFiles = ();
  my $line = "";
  
  # Tool scripts
  my $ScriptFile = new Hydra::Setup::File("script/cdc.tcl", "cdc");
  $line = "";

  my $lib_var = &Hydra::Setup::Flow::get_scenario_lib_var($Paramref, "CDC", "lib");
  $line .= sprintf <<EOF;
source script/cdc_init_library.tcl
source $ENV{HYDRA_HOME}/script/tcl/file_to_list.tcl

set_dofile_abort exit
set_system_mode setup

# Read libraries
read_library -liberty \$$lib_var

# Remove error for redefining variables
set_rule_handling RTL19.3 -severity Warning

# Read design
EOF

  my @incdirs = ();
  my $has_v   = 0;
  my $resolved_rtl_flist = &Hydra::Util::File::resolve_env($rtl_flist);
  if (-f $resolved_rtl_flist) {
    my ($aref_files, $aref_incdirs, $flist_has_v) = &Hydra::Util::File::expand_file_list($resolved_rtl_flist);
    $has_v = $flist_has_v;
    @incdirs = @$aref_incdirs;
  }

  foreach my $incdir (@incdirs) {
    $line .= "add_search_path $incdir\n";
  }

  my $define = $Paramref->get_param_value("CDC_define", "relaxed");
  my $define_string = "";
  if (&Hydra::Setup::Param::has_value($define)) {
    my @defines = split(/\s+/, &Hydra::Setup::Param::remove_param_value_linebreak($define));
    foreach my $d (@defines) {
      $define_string .= "-define $d ";
    }
  }

  $flist_string = "";
  foreach my $flist (@flists) {
    $flist_string .= "[concat [expand_file_list \"${flist}\"]] ";
  }
  $line .= "read_design -sv09 -root ${design_name} ${define_string} ${flist_string}\n";
  
  my $sdc = &Hydra::Util::File::resolve_env($Paramref->get_param_value("CDC_sdc", "strict"));
  $line .= "read_sdc ${sdc}\n";

  $line .= sprintf <<EOF;
report_rule_check -design -error -verbose > rpt/design.rule_check.rpt

# Perform structural CDC checks
set_system_mode verify
add_cdc_check -structural

# Validate command is bugged and requires setup mode
set_system_mode setup
validate -rtl
report_validated_data -summary > rpt/structural.validate.rpt
report_validated_data -verbose > rpt/structural.validate.verbose.rpt

# Use -restart_checkpoint when invoking tool to use this checkpoint
checkpoint -replace db/post_structural.cp

#------------------------------------------------------------------------------
# !!! Structural checks MUST fully pass in order to start functional checks !!!
#------------------------------------------------------------------------------
set_system_mode verify
add_cdc_check -functional

set_system_mode setup
validate -rtl
report_validated_data -summary > rpt/functional.validate.rpt
report_validated_data -verbose > rpt/functional.validate.verbose.rpt

checkpoint -replace db/post_functional.cp

exit

EOF

  $ScriptFile->add_line($line);
  push(@ScriptFiles, $ScriptFile);
  
  return (@LibFiles, @ScriptFiles, $KickoffFile);
}



#++
# Tool: conformal_cd
# Flow: CDC
#--
sub conformal_cd_CDC {
  my ($Paramref) = @_;
  my $design_name = $Paramref->get_param_value("GLOBAL_design", "strict");

  my @LibFiles = &Hydra::Setup::Flow::HYDRA::INIT_LIBRARY($Paramref, "cdc");

  # Run scripts
  my $KickoffFile = new Hydra::Setup::File("HYDRA.run", "cdc");
  #&Hydra::Setup::Flow::write_std_kickoff($Paramref, $KickoffFile, ("script/cdc.tcl"));
  my $time = localtime;
  $KickoffFile->add_line("#!/usr/bin/bash");
  $KickoffFile->add_line("# Generated by Hydra on $time");
  $KickoffFile->add_line("export HYDRA_HOME=$ENV{HYDRA_HOME}");
  $KickoffFile->add_linebreak;

  my $rtl_flist = $Paramref->get_param_value("CDC_rtl_flist", "strict");
  my @flists = split(/\s+/, &Hydra::Setup::Param::remove_param_value_linebreak($rtl_flist));
  my $flist_string = join(" ", map { "\"${_}\"" } @flists);
  $KickoffFile->add_line("\${HYDRA_HOME}/hydra.pl report_git_info -rtl_flist $flist_string -out_file ./rpt/rtl_files.list");
  $KickoffFile->add_linebreak;

  my $tool_command = &Hydra::Setup::Tool::get_tool_command($Paramref, $KickoffFile->get_type, "script/cdc.tcl");
  $KickoffFile->add_line($tool_command);
  $KickoffFile->make_executable;

  my @ScriptFiles = ();
  my $line = "";
  
  # Tool scripts
  my $ScriptFile = new Hydra::Setup::File("script/cdc.tcl", "cdc");
  $line = "";

    my $lib_var = &Hydra::Setup::Flow::get_scenario_lib_var($Paramref, "CDC", "lib");
  $line .= sprintf <<EOF;
source script/cdc_init_library.tcl
source $ENV{HYDRA_HOME}/script/tcl/file_to_list.tcl

set_dofile_abort exit
set_system_mode setup

# Read libraries
read_library -liberty \$$lib_var

# Remove error for redefining variables
set_rule_handling hdl_default_checks/rtl_checks/RTL19.3 -severity Warning

# Read design
EOF

  my @incdirs = ();
  my $has_v   = 0;
  my $resolved_rtl_flist = &Hydra::Util::File::resolve_env($rtl_flist);
  if (-f $resolved_rtl_flist) {
    my ($aref_files, $aref_incdirs, $flist_has_v) = &Hydra::Util::File::expand_file_list($resolved_rtl_flist);
    $has_v = $flist_has_v;
    @incdirs = @$aref_incdirs;
  }

  foreach my $incdir (@incdirs) {
    $line .= "add_search_path $incdir\n";
  }

  my $define = $Paramref->get_param_value("CDC_define", "relaxed");
  my $define_string = "";
  if (&Hydra::Setup::Param::has_value($define)) {
    my @defines = split(/\s+/, &Hydra::Setup::Param::remove_param_value_linebreak($define));
    foreach my $d (@defines) {
      $define_string .= "-define $d ";
    }
  }

  $flist_string = "";
  foreach my $flist (@flists) {
    $flist_string .= "[concat [expand_file_list \"${flist}\"]] ";
  }
  $line .= "read_design -sv09 -root ${design_name} ${define_string} ${flist_string}\n";
  
  my $sdc = &Hydra::Util::File::resolve_env($Paramref->get_param_value("CDC_sdc", "strict"));
  $line .= "read_sdc ${sdc}\n";
  
  $line .= sprintf <<EOF;
report_rule_check -sdc_lint * -status fail -verbose > rpt/sdc_lint.rpt

set_system_mode verify

# Confirm clocks
report_clock_group  > rpt/clock_group.rpt
report_clock        > rpt/clock.rpt
commit_clock

# Extract fifo synchros
add_fifo_instance -default
report_fifo_instance -pass > rpt/fifo.pass.rpt
report_fifo_instance -fail > rpt/fifo.fail.rpt
report_fifo_instance -cdc  > rpt/fifo.cdc.rpt
check_fifo_instance
commit_fifo

# Add rulesets
add_rule_set -file ccd_default_cdc_ruleset.ntcl

checkpoint -replace db/pre_cdc.cp

# Run structural cdc checks
run_rule_check cdc_def_rs
report_rule_check cdc_def_rs -verbose -status fail > rpt/cdc_structural.fail.rpt

checkpoint -replace db/post_structural.cp

#------------------------------------------------------------------------------
# !!! Structural checks MUST fully pass in order to start functional checks !!!
#------------------------------------------------------------------------------
set_attribute [find -ruleinst cdc_def_rs/*/*] analysis_mode "functional"
run_rule_check cdc_def_rs
report_rule_check cdc_def_rs -verbose -status fail > rpt/cdc_functional.fail.rpt

checkpoint -replace db/post_cdc.cp

exit

EOF

  $ScriptFile->add_line($line);
  push(@ScriptFiles, $ScriptFile);
  
  return (@LibFiles, @ScriptFiles, $KickoffFile);
}


=pod

=head1 spyglass CDC

This CDC flow first performs structural checks, then functional checks. Structural checks MUST fully pass before functional checks can be performed. Re-run this flow when you have finished fixing structural failures to run functional checks.

=over

=item CDC_rtl_flist

An flist containing RTL files. This will be read by Hydra to determine what include directories to pass into the tool.

=item CDC_define

A space-delimited list of `define macros.

=item CDC_sdc

The timing constraint file. This will be used if CDC_sgdc is not specified.

=item CDC_sgdc

A SpyGlass Design Constraint file. Optional. If a file is not specified, Hydra will generate a local sgdc with data from other params.

=item CDC_source_catchall_local

A space-delimited list of misc source scripts.

=item CDC_source_catchall_global

A space-delimited list of misc source scripts.

=back

=head1 conformal_ec CDC

This CDC flow first performs structural checks, then functional checks. Structural checks MUST fully pass before functional checks can be performed. Re-run this flow when you have finished fixing structural failures to run functional checks.

=over

=item CDC_rtl_flist

An flist containing RTL files. This will be read by Hydra to determine what include directories to pass into the tool.

=item CDC_define

A space-delimited list of `define macros.

=item CDC_sdc

The timing constraint file.

=back

=head1 conformal_cd CDC

This CDC flow first performs structural checks, then functional checks. Structural checks MUST fully pass before functional checks can be performed. Re-run this flow when you have finished fixing structural failures to run functional checks.

=over

=item CDC_rtl_flist

An flist containing RTL files. This will be read by Hydra to determine what include directories to pass into the tool.

=item CDC_define

A space-delimited list of `define macros.

=item CDC_sdc

The timing constraint file.

=back

=cut

1;
