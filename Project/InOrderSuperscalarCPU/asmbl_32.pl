#!/usr/bin/perl -w



#USAGE:

#

# asmbl.pl <infile> [ > <outfile> ]



#NOTES:

# -All labels MUST start with L

# -Shift amounts must be in decimal

# -Immediate may be in hex or decimal.  If in hex, precede with "0x"

# -Comments may be specified with either "#" or "//".  

# -No multiline comments

#

# MEM <ADDR> and DATA <VALUE> may be used to specify memory

#





#################################################################





use strict;



if(@ARGV < 1) { print "Usage: asmbl.pl <input assembly file> > outputFile\n"; exit; }





my %regs = ("R0" => "00000", "R1" => "00001", "R2" => "00010", "R3" => "00011",

        "R4" => "00100", "R5" => "00101", "R6" => "00110", "R7" => "00111",

        "R8" => "01000", "R9" => "01001", "R10"=> "01010", "R11"=> "01011",

        "R12"=> "01100", "R13"=> "01101", "R14"=> "01110", "R15"=> "01111",

        "R16"=> "10000", "R17"=> "10001", "R18"=> "10010", "R19"=> "10011",

        "R20"=> "10100", "R21"=> "10101", "R22"=> "10110", "R23"=> "10111",

        "R24"=> "11000", "R25"=> "11001", "R26"=> "11010", "R27"=> "11011",

        "R28"=> "11100", "R29"=> "11101", "R30"=> "11110", "R31"=> "11111");



my %conds = ("NEQ" => "000", "EQ" => "001", "GT" => "010", "LT" => "011", "GTE" => "100", "LTE" => "101", "OVFL" => "110", "UNCOND" => "111");



my %numArgs = ( qw/ADD 3 ADDZ 3 SUB 3 AND 3 NOR 3 SLL 3 SRL 3 SRA 3 LW 3 SW 3 LHB 2 LLB 2 B 2 JAL 1 JR 1 LWI 3 PUSH 1 POP 1 ADDI 3 SUBI 3 MUL 3 UMUL 3 ADDF 3 SUBF 3 MULF 3 ITF 2 FTI 2 HLT 0/);



my %opcode = ( qw/ADD 00000 ADDZ 00001 SUB 00010 AND 00011 NOR 00100 SLL 00101 SRL 00110 SRA 00111 LW 01000 SW 01001 LHB 01010 LLB 01011 B 01100 JAL 01101 JR 01110 LWI 10000 PUSH 10010 POP 10011 ADDI 10100 SUBI 10101 MUL 11000 UMUL 11001 ADDF 11010 SUBF 11011 MULF 11100 ITF 11101 FTI 11110 HLT 11111/);



my %rlookup = ( "1111", "F" , "1110", "E" , "1101", "D" , "1100", "C",

                "1011", "B" , "1010", "A" , "1001", "9" , "1000", "8",

                "0111", "7" , "0110", "6" , "0101", "5" , "0100", "4",

                "0011", "3" , "0010", "2" , "0001", "1" , "0000", "0");





open(IN, "$ARGV[0]") or die("Can't open $ARGV[0]: $!");



my %labels = ( );

my @mem;

my @code;

my @source_lines;

my $addr = 0;



while(<IN>) {

    my $bits = "";



    s/\#(.*)$//;  #remove  (#) comments

    s#//(.*)$##;  #remove (//) comments

    next if( /^\s*$/ );  #skip blank lines



    if(/MEM\s+(\S*)/) {

    $addr = hex($1);

    next;

    }

    if(/DATA\s+(.*)/) {

    my $data = $1;

    $data =~ s/\s*(\S+)\s*/$1/;

    while(length($data) < 4) { $data = "0" . $data }

    $mem[$addr++] = hexToBin($data, 32);

    next;

    }

    $source_lines[$addr] = $_;

    $source_lines[$addr] =~ s/^\s+|\s+$//g;

    $_ = uc($_);



  if(s/(.*)://) {  #capture labels

    my $label = $1;

    $label =~ s/\s*(\S+)\s*/$1/;   #strip white space

    $labels{$label} = $addr;

  }



  if( /^\s*(\S+)\s*(.*)/ ) {

      my $instr = $1;

      my @args = split(",", $2);

      

      if(!exists($numArgs{$instr})) { die("Unknown instruction\n$_") }

      if($numArgs{$instr} != @args) { 

      die("Error:\n$_\nWrong number of arguments (need $numArgs{$instr} args)\n") 

      }

      

      $bits = "$opcode{$instr}";



      #strip whitespace from arguments

      for(my $c=0; $c<@args; $c++) { 

      $args[$c] =~ s/^\s*(\S+)\s*$/$1/ ;

      }

      

      if($instr =~ /^(AND|NOR|ADD|ADDZ|SUB|MUL|UMUL|ADDF|SUBF|MULF)$/) {

      $bits .= "000";

      foreach my $reg ($args[0], $args[1], $args[2]) {

          if(!$regs{$reg}) { die("Bad register ($reg)\n$_") }

          $bits .= "000".$regs{$reg};

      }

      }

      elsif($instr =~ /^(SRA|SLL|SRL)$/) {

      $bits .= "000";

      foreach my $reg ($args[0], $args[1]) {

          if(!$regs{$reg}) { die("Bad register ($reg)\n$_") }

          $bits .= "000".$regs{$reg};

      }

      $bits .= "000".parseImmediate($args[2], 5);

      }

      elsif($instr =~ /^(LW|SW|LWI|ADDI|SUBI)$/) {

      $bits .= "000";

      foreach my $reg ($args[0], $args[1]) {

          if(!$regs{$reg}) { die("Bad register ($reg)\n$_") }

          $bits .= "000".$regs{$reg};

      }

      $bits .= parseImmediate($args[2], 8);

      }

      elsif($instr =~ /^(LHB|LLB)$/) {

      $bits .= "000";

      foreach my $reg ($args[0]) {

          if(!$regs{$reg}) { die("Bad register ($reg)\n$_") }

          $bits .= "000".$regs{$reg};

      }

      $bits .= parseImmediate($args[1], 16);

      }

      elsif($instr =~ /^(B)$/) {

      if(!$conds{$args[0]}) { die("Invalid condition code ($args[0])\n$_\nUse only from {NEQ, EQ, GT, LT, GTE, LTE, OVFL, UNCOND}") }

      else { $bits .= $conds{$args[0]}; }



      if($args[1] !~ /[a-zA-Z]/) { print STDERR "Error: Invalid label name: \"$args[1]\" in line:\n$_"; exit; }

      $bits .= "000000000000" .  "|" . $args[1] . "|12|B|";

      }

      elsif($instr =~ /^(JAL)$/) {

      if($args[0] !~ /[a-zA-Z]/) { print STDERR "Error: Invalid label name: \"$args[0]\" in line:\n$_"; exit; }

      $bits .= "000000000000000" . "|" . $args[0] . "|12|J|";

      }

      elsif($instr =~ /^(JR|PUSH)$/) {

        foreach my $reg ($args[0]) {

          if(!$regs{$reg}) { die("Bad register ($reg)\n$_") }

          $bits .= "00000000000000" . $regs{$reg} . "00000000";

        }

      }

      elsif($instr =~ /^(POP)$/) {

        foreach my $reg ($args[0]) {

          if(!$regs{$reg}) { die("Bad register ($reg)\n$_") }

          $bits .= "000000" . $regs{$reg} . "0000000000000000";

        }

      }

      elsif($instr =~ /^(ITF|FTI)$/) {

      $bits .= "000";

      foreach my $reg ($args[0], $args[1]) {

          if(!$regs{$reg}) { die("Bad register ($reg)\n$_") }

          $bits .= "000".$regs{$reg};

      }

      $bits .= "00000000";

      }

      elsif($instr =~ /^(HLT)$/) {
    $bits .= "000000000000000000000000000";

      }

      #print $bits;

      $mem[$addr] = $bits;

      $code[$addr] = $_;

      $addr += 1;

  }    

}

close(IN);



# print "DEPTH = 64;\n";

# print "WIDTH = 32;\n";

# print "ADDRESS_RADIX = HEX;\n";

# print "DATA_RADIX = HEX;\n";

# print "CONTENT\n";

# print "BEGIN\n";

#print "@"."0\n";



for(my $i=0; $i<scalar(@mem); $i++) {

  $addr = $mem[$i];

  next if(!$addr);
 
  if($addr =~ /\|(.+)\|(\d+)\|(\w)\|/) { 

    if(!$labels{$1}) { die("Error:\nLabel referenced, but doesnt exist ($1)\n") }

    my $disp = $labels{$1} - $i - 1;
#    my $disp = ($3 eq "J") ? $labels{$1} : ($labels{$1} - ($i*2 + 2)) / 2;

    $disp = decToBin($disp, $2);

    $addr =~ s/\|(.+)\|(\d+)\|(\w)\|/$disp/;

  }

  #my $j = $i / 2;  #shift from a byte address to a word address

  # print decToHex($i) . "  :  " . binToHex($addr) . "  ;\n";
    
  print "\@" . decToHex($i, 4) . " " . binToHex($addr) . "\t// " . $source_lines[$i] . "\n";

  #if($code[$i]) { print $code[$i] }

  #else { print "\n" }

}







sub parseImmediate {

    my $imm = $_[0];

    my $hex = ($imm =~ /^0x/i) ? 1 : 0;

    $imm =~ s/^0x//i if($hex);

    return $hex ? hexToBin($imm, $_[1]) : decToBin($imm, $_[1]);

}



sub hexToBin {

  return decToBin(hex($_[0]), $_[1]);

}



sub decToBin {

    my $ret = sprintf("%b", $_[0]);

    while(length($ret) < $_[1]) { $ret = "0" . $ret }

    if(length($ret) > $_[1]) { $ret = substr($ret, length($ret)-$_[1]) }

    return $ret;

}







sub decToHex {

  my $ret = sprintf("%x", $_[0]);

  while(length($ret) < 4) { $ret = "0" . $ret }

  return $ret;

}



sub binToHex {

  $_[0] =~ /(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})/;

  return $rlookup{$1} . $rlookup{$2} . $rlookup{$3} . $rlookup{$4} . $rlookup{$5} . $rlookup{$6} . $rlookup{$7} . $rlookup{$8}; 

}



