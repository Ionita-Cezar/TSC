/***********************************************************************
 * A SystemVerilog testbench for an instruction register.
 * The course labs will convert this to an object-oriented testbench
 * with constrained random test generation, functional coverage, and
 * a scoreboard for self-verification.
 **********************************************************************/

module instr_register_test
  import instr_register_pkg::*;  // user-defined types are defined in instr_register_pkg.sv
  (input  logic          clk,
   output logic          load_en,
   output logic          reset_n,
   output operand_t      operand_a,
   output operand_t      operand_b,
   output opcode_t       opcode,
   output address_t      write_pointer,
   output address_t      read_pointer,
   input  instruction_t  instruction_word
  );

  timeunit 1ns/1ns;

  parameter RD_NR = 20;
  parameter WR_NT = 20;

  int seed = 555;
  int exp_result = 0;

  instruction_t save_data [0:31];

  initial begin
    $display("\n\n***********************************************************");
    $display(    "***  THIS IS A SELF-CHECKING TESTBENCH.  YOU DON'T      ***");
    $display(    "***  NEED TO VISUALLY VERIFY THAT THE OUTPUT VALUES     ***");
    $display(    "***  MATCH THE INPUT VALUES FOR EACH REGISTER LOCATION  ***");
    $display(    "***********************************************************");

    $display("\nReseting the instruction register...");
    write_pointer  = 5'h00;         // initialize write pointer
    read_pointer   = 5'h1F;         // initialize read pointer
    load_en        = 1'b0;          // initialize load control line
    reset_n       <= 1'b0;          // assert reset_n (active low)
    repeat (2) @(posedge clk) ;     // hold in reset for 2 clock cycles
    reset_n        = 1'b1;          // deassert reset_n (active low)

    $display("\nWriting values to register stack...");
    @(posedge clk) load_en = 1'b1;  // enable writing to register
    // repeat (3) begin - 11/03/2024 - IC
    repeat (WR_NT) begin
      @(posedge clk) randomize_transaction;
      @(negedge clk) print_transaction;
      save_test_data;
      // test_data;
    end
    @(posedge clk) load_en = 1'b0;  // turn-off writing to register

    // read back and display same three register locations
    $display("\nReading back the same register locations written...");
    // for (int i=0; i<=2; i++) begin - 11/03/2024 - IC
    for (int i=0; i<=RD_NR; i++) begin
      // later labs will replace this loop with iterating through a
      // scoreboard to determine which addresses were written and
      // the expected values to be read back
      @(posedge clk) read_pointer = i;
      @(negedge clk) print_results;
      check_result;
    end

    @(posedge clk) ;
    $display("\n***********************************************************");
    $display(  "***  THIS IS A SELF-CHECKING TESTBENCH.  YOU DON'T      ***");
    $display(  "***  NEED TO VISUALLY VERIFY THAT THE OUTPUT VALUES     ***");
    $display(  "***  MATCH THE INPUT VALUES FOR EACH REGISTER LOCATION  ***");
    $display(  "***********************************************************\n");
    $finish;
  end

  function void randomize_transaction;
    // A later lab will replace this function with SystemVerilog
    // constrained random values
    //
    // The stactic temp variable is required in order to write to fixed
    // addresses of 0, 1 and 2.  This will be replaceed with randomizeed
    // write_pointer values in a later lab
    //
    static int temp = 0;
    operand_a     <= $random(seed)%16;                 // between -15 and 15
    operand_b     <= $unsigned($random)%16;            // between 0 and 15
    opcode        <= opcode_t'($unsigned($random)%8);  // between 0 and 7, cast to opcode_t type
    write_pointer <= temp++;
  endfunction: randomize_transaction

  function void print_transaction;
    $display("Writing to register location %0d: ", write_pointer);
    $display("  opcode = %0d (%s)", opcode, opcode.name);
    $display("  operand_a = %0d",   operand_a);
    $display("  operand_b = %0d\n", operand_b);
  endfunction: print_transaction

  function void save_test_data;
      case (opcode)     // Perform operation based on opcode
        ZERO:     save_data[write_pointer] = '{opcode, operand_a, operand_b, {64{1'b0}}};
        PASSA:    save_data[write_pointer] = '{opcode, operand_a, operand_b, operand_a};
        PASSB:    save_data[write_pointer] = '{opcode, operand_a, operand_b, operand_b};
        ADD:      save_data[write_pointer] = '{opcode, operand_a, operand_b, operand_a + operand_b};
        SUB:      save_data[write_pointer] = '{opcode, operand_a, operand_b, operand_a - operand_b};
        MULT:     save_data[write_pointer] = '{opcode, operand_a, operand_b, operand_a * operand_b};
        DIV:      save_data[write_pointer] = '{opcode, operand_a, operand_b, operand_b == 0 ? 0 : operand_a / operand_b};
        MOD:      save_data[write_pointer] = '{opcode, operand_a, operand_b, operand_a % operand_b};
        default:  save_data[write_pointer] = '{opc:ZERO, default:0};
      endcase



  endfunction: save_test_data

  // function void test_data;
  //   if(save_data[write_pointer] != instruction_word)
  //   $display("Data mismatch at register location %0d", write_pointer);
  // endfunction

  function void print_results;
    $display("Read from register location %0d: ", read_pointer);
    $display("  opcode = %0d (%s)", instruction_word.opc, instruction_word.opc.name);
    $display("  operand_a = %0d",   instruction_word.op_a);
    $display("  operand_b = %0d\n", instruction_word.op_b);
    $display("  result = %0d\n",    instruction_word.res);
  endfunction: print_results

  function void check_result;
  exp_result = 0;

  if(instruction_word.opc == ZERO)
    exp_result = 0;
  else if(instruction_word.opc == PASSA)
    exp_result = instruction_word.op_a;
  else if(instruction_word.opc == PASSB)
    exp_result = instruction_word.op_b;
  else if(instruction_word.opc == ADD)
    exp_result = instruction_word.op_a + instruction_word.op_b;
  else if(instruction_word.opc == SUB)
    exp_result = instruction_word.op_a - instruction_word.op_b;
  else if(instruction_word.opc == MULT)
    exp_result = instruction_word.op_a * instruction_word.op_b;
  else if(instruction_word.opc == DIV) begin
    if(instruction_word.op_b == 0)
      exp_result = 0;
    else
      exp_result = instruction_word.op_a / instruction_word.op_b;
  end
  else if(instruction_word.opc == MOD) begin
    if(instruction_word.op_b == 0)
      exp_result = 0;
    else
      exp_result = instruction_word.op_a % instruction_word.op_b;
  end

  if(exp_result != instruction_word.res)
    $display("ERROR");

  endfunction: check_result

endmodule: instr_register_test