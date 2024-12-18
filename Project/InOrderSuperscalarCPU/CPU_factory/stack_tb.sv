////////////////////////////////////////////////////////
//
// 32-bit x 1024 stack TESTBENCH
// 
// Designer: Harry Zhao
//
// The stack allows performing two operations in a single 
// cycle. The operations are from two seperate intrstions.
// Each instruction can only perform one action at a time.
// eg. PUSH0 & POP0 is not allowed
//
///////////////////////////////////////////////////////
// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module stack_tb();

  logic clk, rst_n;
  logic push0, push1, pop0, pop1;
  logic [31:0] wdata0, wdata1;
  logic [31:0] rdata0, rdata1;
  logic [31:0] wdata;
  logic random_branch;

  stack iDUT(.clk(clk), 
             .rst_n(rst_n), 
             .push0(push0), 
             .push1(push1), 
             .pop0(pop0), 
             .pop1(pop1), 
             .wdata0(wdata0),
             .wdata1(wdata1),
             .stack0_EX_DM(rdata0), 
             .stack1_EX_DM(rdata1)
             );

  logic [31:0] local_stack [1023:0];

  initial begin
    clk = 1'b0;          // assumed to be 50MHz
    rst_n = 1'b0;        // only reset the DUT here once throughout this TB
    push0 = 1'b0;
    pop0 = 1'b0;
    push1 = 1'b0;
    pop1 = 1'b0;
    random_branch = 1'b0;
    //set signals on negedge, check data on the next negedge
    //    ____   ____   ____
    // ___|  |___|  |___|  |
    //       ^      ^
    //      set    check 
  
    //    ____   ____   ____
    // ___|  |___|  |___|  |
    //       ^      ^      ^
    //      push   pop    check
    @(posedge clk);
    @(negedge clk) rst_n = 1'b1;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Test Part 0 : Only perform operations with one port activated. (The two ports will not be activated at the same time)//
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    /////////////////////////////////////////////////////////////////////////////////////////
    // -> Test 0 :  Push one random data and pop the data out to confirm the data.(port 0) //
    /////////////////////////////////////////////////////////////////////////////////////////
    for(int i = 0; i < 10000; i++) begin
      @(negedge clk);
      wdata0 = $random();
      push0 = 1'b1;
      pop0 = 1'b0;

      @(negedge clk);
      push0 = 1'b0;
      pop0 = 1'b1;

      @(negedge clk);
      pop0 = 1'b0; // stop popping data when check
      if (rdata0 !== wdata0) begin
        $display("TEST 0-0 failed at port 0: push data %h != pop data %h", wdata0, rdata0);
        $stop();
      end
    end
    $display("TEST 0-0 passed: push one data and pop one data passes after 10000 random tests at port 0");

    /////////////////////////////////////////////////////////////////////////////////////////
    // -> Test 1 :  Push one random data and pop the data out to confirm the data.(port 1) //
    /////////////////////////////////////////////////////////////////////////////////////////
    for(int i = 0; i < 10000; i++) begin
      @(negedge clk);
      wdata1 = $random();
      push1 = 1'b1;
      pop1 = 1'b0;

      @(negedge clk);
      push1 = 1'b0;
      pop1 = 1'b1;

      @(negedge clk);
      pop1 = 1'b0; // stop popping data when check
      if (rdata1 !== wdata1) begin
        $display("TEST 0-1 failed at port 1: push data %h != pop data %h", wdata1, rdata1);
        $stop();
      end
    end
    $display("TEST 0-1 passed: push one data and pop one data passes after 10000 random tests at port 1");

    //////////////////////////////////////////////////////////////////////////////////////////////
    // -> Test 2 :  Push one random data and pop the data out to confirm the data.(mixed ports) //
    //////////////////////////////////////////////////////////////////////////////////////////////
    for(int i = 0; i < 10000; i++) begin
      random_branch = $random();
      @(negedge clk);  // choose the port to perform push
      // use wdata0 to push
      pop0 = 1'b0;
      pop1 = 1'b0;
      if (random_branch) begin
        wdata1 = $random();
        wdata = wdata1;
        push1 = 1'b1;
      end else begin
        wdata0 = $random();
        wdata = wdata0;
        push0 = 1'b1;
      end

      random_branch = $random();
      @(negedge clk);  // choose the port to perform pop
      push1 = 1'b0;
      push0 = 1'b0;
      if (random_branch) begin
        pop1 = 1'b1;
      end else begin
        pop0 = 1'b1;
      end

      
      @(negedge clk);
      pop0 = 1'b0; // stop popping data when check
      pop1 = 1'b0; // stop popping data when check
      if (random_branch) begin
        if (rdata1 !== wdata) begin
          $display("TEST 0-2 failed when pop at port 1: push data %h != pop data %h", wdata, rdata1);
          $stop();
        end
      end else
        if (rdata0 !== wdata) begin
          $display("TEST 0-2 failed when pop at port 0: push data %h != pop data %h", wdata, rdata0);
          $stop();
        end
    end
    $display("TEST 0-2 passed: push one data and pop one data passes after 10000 random tests at port 1");

    /////////////////////////////////////////////////////////////////////////////////////////////////////
    // Test 3: Overflow the stack and pop all elements to make sure the first 1024 pushes are saved.  //
    ///////////////////////////////////////////////////////////////////////////////////////////////////
    // 
    // Fill the stack
    for(int i = 0; i < 1024; i++) begin
      @(negedge clk);
      random_branch = $random();
      pop0 = 1'b0;
      pop1 = 1'b1;
      if (random_branch) begin
        wdata1 = $random();
        push0 = 1'b0;
        push1 = 1'b1;
        local_stack[i] = wdata1;
      end else begin
        wdata0 = $random();
        push0 = 1'b1;
        push1 = 1'b0;
        local_stack[i] = wdata0;
      end
    end
    // Overflow the stack
    for(int i = 0; i < 2000; i++) begin
      @(negedge clk);
      random_branch = $random();
      if (random_branch) begin
        wdata1 = $random();
        wdata = wdata1;
        push1 = 1'b1;
        push0 = 1'b0;
      end else begin
        wdata0 = $random();
        wdata = wdata0;
        push0 = 1'b1;
        push1 = 1'b0;
      end
    end
    // Retrive the data from the stack
    push1 = 1'b0;
    push0 = 1'b0;
    for(int i = 1023; i >= 0; i--) begin
      @(negedge clk);
      random_branch = $random();
      if (random_branch) begin
        pop0 = 1'b0;
        pop1 = 1'b1;
      end else begin
        pop0 = 1'b1;
        pop1 = 1'b0;
      end
      @(negedge clk);
      pop0 = 1'b0;
      pop1 = 1'b0;
      if (random_branch & rdata1 !== local_stack[i]) begin
        $display("TEST 0-3 failed: push data %h != pop data %h at iter %d", local_stack[i], rdata1, i);
        $stop();
      end else if (rdata0 !== local_stack[i]) begin
        $display("TEST 0-3 failed: push data %h != pop data %h at iter %d", local_stack[i], rdata0, i);
        $stop();
      end
    end
    $display("TEST 0-3 passed: all 1024 data are retrived correctly after overflowing the stack");


    //////////////////////////////////////////////////////////////
    // Test Part 1 : Perform operations with both port enabled. //
    //////////////////////////////////////////////////////////////

/*
    /////////////////////////////////////////////////////////////////////////////////////////////////////
    // Test 2: Overflow the stack and pop all elements to make sure the first 1024 pushes are saved.  //
    ///////////////////////////////////////////////////////////////////////////////////////////////////
    // 
    // Fill the stack
    for(int i = 0; i < 1024; i++) begin
      @(posedge clk);
      wdata = $random();
      local_stack[i] = wdata;
      push = 1'b1;
      pop = 1'b0;
    end
    // Overflow the stack
    for(int i = 0; i < 2000; i++) begin
      @(posedge clk);
      wdata = $random();
      push = 1'b1;
      pop = 1'b0;
    end
    // Retrive the data from the stack
    for(int i = 1023; i >= 0; i--) begin
      @(posedge clk);
      push = 1'b0;
      pop = 1'b1;
      @(posedge clk);
      pop = 1'b0;
      if (rdata !== local_stack[i]) begin
        $display("TEST 2 failed: push data %h != pop data %h at iter %d", local_stack[i], rdata, i);
        $stop();
      end
    end
    $display("TEST 2 passed: all 1024 data are retrived correctly after overflowing the stack");

    ////////////////////////////////////////////////////
    // Test 3: Underflow the stack and repeat test1  //
    //////////////////////////////////////////////////
    // 
    // Under flow the stack
    for(int i = 0; i < 2000; i++) begin
      @(posedge clk);
      wdata = $random();
      push = 1'b0;
      pop = 1'b1;
    end
    // Repeat this test 10000 times
    for(int i = 0; i < 10000; i++) begin
      @(posedge clk);
      wdata = $random();
      push = 1'b1;
      pop = 1'b0;

      @(posedge clk);
      push = 1'b0;
      pop = 1'b1;

      @(posedge clk);
      pop = 1'b0;
      if (rdata !== wdata) begin
        $display("TEST 3 failed: push data %h != pop data %h after underflow", wdata, rdata);
        $stop();
      end
    end

    $display("TEST 3 passed: test 1 and test 2 still works after underflow the stack.");
*/
    $display("Yahoo!! All tests passed");
    $stop();
  end

  always
    #5 clk = ~clk;

endmodule
